from __future__ import annotations

import copy
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from zipfile import ZipFile

from importer.book_importer import (
    BookImporter, BookPackageCompiler, FlutterMarkdownConverter, ImporterError,
    DEFAULT_NEXUS_MOBILE, DEFAULT_FLUTTER, appflowy_content_hash,
)
from importer.heading_sources import SourceError, FlutterSourceValidator, file_hash
from importer.tests.helpers import FakeMarkdownConverter, FakeKgqlClient, create_package

EXTRACTOR = Path('/Users/nathikazad/.codex/skills/book-to-appflowy-summaries/scripts/extract_epub.py')


def extractor():
    spec = importlib.util.spec_from_file_location('nx_test_extract_epub', EXTRACTOR)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def fixture_epub(path):
    with ZipFile(path, 'w') as archive:
        archive.writestr('mimetype', 'application/epub+zip')
        archive.writestr('META-INF/container.xml', '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OPS/content.opf"/></rootfiles></container>')
        archive.writestr('OPS/content.opf', '''<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Sample Book</dc:title><dc:creator>Test</dc:creator><dc:identifier id="id">test</dc:identifier></metadata><manifest><item id="toc" href="toc.ncx" media-type="application/x-dtbncx+xml"/><item id="one" href="one.xhtml" media-type="application/xhtml+xml"/></manifest><spine toc="toc"><itemref idref="one"/></spine></package>''')
        archive.writestr('OPS/toc.ncx', '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/"><head/><docTitle><text>Sample</text></docTitle><navMap><navPoint id="one" playOrder="1"><navLabel><text>First</text></navLabel><content src="one.xhtml"/></navPoint></navMap></ncx>')
        archive.writestr('OPS/one.xhtml', '<html xmlns="http://www.w3.org/1999/xhtml"><body><h1 id="first">First Ideas</h1><p id="passage">A useful passage about choices &amp; consequences.</p><h2 id="repeat-a">Repeated heading</h2><p>A different passage.</p><h2 id="repeat-b">Repeated heading</h2><p>Last passage.</p></body></html>')


def linked_package(root):
    epub = root / 'source.epub'
    fixture_epub(epub)
    package = create_package(root)
    extractor().extract(epub, package / 'sources')
    catalog = json.loads((package / 'sources/epub-anchors.json').read_text())
    key = next(k for k, v in catalog['anchors'].items() if v.get('fragment') == 'passage')
    config_path = package / 'book.json'
    config = json.loads(config_path.read_text())
    config['epub_sources'] = 'sources/epub-anchors.json'
    for chapter in config['chapters']:
        relative = f"chapters/ch0{chapter['number']}.sources.json"
        chapter['heading_sources'] = relative
        (package / relative).write_text(json.dumps({'schema_version': 1, 'headings': [
            {'ordinal': 1, 'level': 2, 'text': 'Main Point', 'source_id': key}
        ]}))
    config_path.write_text(json.dumps(config))
    return package, epub


class RecordingValidator:
    def validate(self, epub, chapters):
        self.chapters = copy.deepcopy(chapters)


class HeadingSourcesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.package, self.epub = linked_package(Path(self.temp.name))
        self.validator = RecordingValidator()
        self.compiler = BookPackageCompiler(FakeMarkdownConverter(), self.validator)

    def compile(self):
        path = self.compiler.compile(self.package, epub_path=self.epub)
        return json.loads(path.read_text())

    def edit_json(self, relative, change):
        path = self.package / relative
        value = json.loads(path.read_text())
        change(value)
        path.write_text(json.dumps(value))

    def test_extraction_preserves_real_locations_and_is_deterministic(self):
        before = (self.package / 'sources/epub-anchors.json').read_bytes()
        extractor().extract(self.epub, self.package / 'sources')
        self.assertEqual(before, (self.package / 'sources/epub-anchors.json').read_bytes())
        catalog = json.loads(before)
        self.assertEqual(catalog['sha256'], file_hash(self.epub))
        self.assertEqual(len(catalog['anchors']), 6)
        self.assertTrue(all(a['resource'] == 'OPS/one.xhtml' for a in catalog['anchors'].values()))
        markdown = next((self.package / 'sources/spine').glob('*.md')).read_text()
        self.assertEqual(markdown.count('<!-- EPUB_SOURCE:'), 6)
        self.assertIn('choices & consequences.', markdown)

    def test_compile_attaches_sources_before_hashing_and_is_deterministic(self):
        manifest = self.compile()
        self.assertEqual(manifest, self.compile())
        chapter = manifest['chapters'][0]
        heading = chapter['kgql_json_document']['document']['children'][0]
        source = heading['data']['book_source']
        self.assertEqual(source['book_id'], 77)
        self.assertEqual(source['fragment'], 'passage')
        self.assertEqual(source['sha256'], file_hash(self.epub))
        self.assertEqual(chapter['publish']['content_hash'], appflowy_content_hash(chapter['kgql_json_document']))
        self.assertNotIn('book_source', chapter['short_appflowy_block']['data'])
        self.assertEqual(chapter['source_coverage'], {'linked': 1, 'unlinked': []})
        self.assertEqual(self.validator.chapters, manifest['chapters'])

    def test_heading_mismatch_missing_and_unknown_mapping_fail(self):
        path = self.package / 'chapters/ch01.sources.json'
        original = json.loads(path.read_text())
        for key, value in [('ordinal', 2), ('text', 'Changed'), ('level', 3), ('source_id', 'unknown')]:
            modified = copy.deepcopy(original)
            modified['headings'][0][key] = value
            path.write_text(json.dumps(modified))
            with self.assertRaises(SourceError):
                self.compile()
        path.write_text(json.dumps({'schema_version': 1, 'headings': []}))
        with self.assertRaisesRegex(SourceError, 'Every detailed heading'):
            self.compile()

    def test_unlinked_requires_reason_and_is_reported(self):
        def update(value):
            value['headings'][0].pop('source_id')
        self.edit_json('chapters/ch01.sources.json', update)
        with self.assertRaisesRegex(SourceError, 'unlinked_reason'):
            self.compile()
        self.edit_json('chapters/ch01.sources.json', lambda v: v['headings'][0].update(unlinked_reason='Synthesis across the chapter'))
        chapter = self.compile()['chapters'][0]
        self.assertNotIn('book_source', chapter['kgql_json_document']['document']['children'][0]['data'])
        self.assertEqual(chapter['source_coverage']['linked'], 0)
        self.assertEqual(len(chapter['source_coverage']['unlinked']), 1)

    def test_missing_epub_wrong_hash_and_path_traversal_fail(self):
        with self.assertRaisesRegex(SourceError, '--epub'):
            self.compiler.compile(self.package)
        self.edit_json('book.json', lambda c: c.update(epub_sources='../outside.json'))
        with self.assertRaisesRegex(SourceError, 'escapes'):
            self.compile()
        self.edit_json('book.json', lambda c: c.update(epub_sources='sources/epub-anchors.json'))
        self.edit_json('sources/epub-anchors.json', lambda c: c.update(sha256='0' * 64))
        with self.assertRaisesRegex(SourceError, 'hash'):
            self.compile()

    def test_import_checks_attachment_and_preserves_overview_and_metadata(self):
        manifest = self.compile()
        client = FakeKgqlClient(77, 'Sample Book')
        importer = BookImporter(client)
        with self.assertRaisesRegex(ImporterError, 'Uploaded Book EPUB hash'):
            importer.plan(manifest)
        self.assertEqual(client.mutations, [])
        client.book['book_file'] = {'sha256': file_hash(self.epub), 'link': '/books/77.epub', 'position': {'block': 4}}
        before = copy.deepcopy(client.book['book_file'])
        importer.execute(manifest, self.package / 'receipt.json')
        self.assertEqual(before, client.book['book_file'])
        self.assertNotIn('book_source', json.dumps(client.book['json_document']))
        self.assertIn('book_source', json.dumps(client.chapters))
        manifest['chapters'][0]['kgql_json_document']['document']['children'][0]['data']['book_source']['book_id'] = 99
        with self.assertRaisesRegex(ImporterError, 'identity/hash/type'):
            importer.plan(manifest)

    @unittest.skipUnless(os.environ.get('NX_SOURCE_INTEGRATION') == '1', 'opt-in real Flutter converter/resolver')
    def test_real_converter_resolver_and_ambiguous_or_missing_targets(self):
        self.compiler = BookPackageCompiler(FlutterMarkdownConverter())
        manifest = self.compile()
        validator = FlutterSourceValidator(DEFAULT_NEXUS_MOBILE, DEFAULT_FLUTTER)
        for quote in ['Repeated heading', 'This does not exist']:
            chapters = copy.deepcopy(manifest['chapters'])
            reference = chapters[0]['kgql_json_document']['document']['children'][0]['data']['book_source']
            reference.pop('fragment')
            reference['quote'] = {'exact': quote}
            with self.assertRaises(SourceError):
                validator.validate(self.epub, chapters)


if __name__ == '__main__':
    unittest.main()
