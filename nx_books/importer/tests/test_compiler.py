from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from importer.book_importer import (
    BookPackageCompiler,
    ImporterError,
    appflowy_content_hash,
)
from importer.tests.helpers import FakeMarkdownConverter, create_package


class BookPackageCompilerTest(unittest.TestCase):
    def test_compile_creates_deterministic_import_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = create_package(Path(directory))
            manifest_path = BookPackageCompiler(
                FakeMarkdownConverter()
            ).compile(package)
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

            self.assertEqual(manifest["schema_version"], 1)
            self.assertEqual(manifest["book"]["kgql_id"], 77)
            self.assertEqual(len(manifest["chapters"]), 2)
            chapter = manifest["chapters"][0]
            self.assertEqual(chapter["document_name"], "Chapter 1: First Ideas")
            self.assertEqual(chapter["short_summary"].count("\n"), 0)
            self.assertEqual(
                chapter["detailed_appflowy_document"]["document"]["children"][0][
                    "data"
                ]["level"],
                1,
            )
            stored_children = chapter["kgql_json_document"]["document"][
                "children"
            ]
            self.assertEqual(stored_children[0]["data"]["level"], 2)
            self.assertEqual(
                chapter["publish"]["content_hash"],
                appflowy_content_hash(chapter["kgql_json_document"]),
            )
            self.assertTrue(
                (package / "build/markdown/detailed-summary-ch1.md").is_file()
            )
            self.assertTrue(
                (
                    package
                    / "build/markdown/detailed-summary-ch1.appflowy.json"
                ).is_file()
            )

    def test_compile_rejects_multiple_short_paragraphs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = create_package(
                Path(directory), two_short_paragraphs=True
            )
            with self.assertRaisesRegex(
                ImporterError, "short summary must be exactly one paragraph"
            ):
                BookPackageCompiler(FakeMarkdownConverter()).compile(package)

    def test_compile_rejects_h1_inside_detailed_summary(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = create_package(Path(directory))
            chapter = package / "chapters/ch01.md"
            chapter.write_text(
                chapter.read_text(encoding="utf-8").replace(
                    "## Main Point", "# Repeated Chapter Title"
                ),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ImporterError, "must not contain an H1"):
                BookPackageCompiler(FakeMarkdownConverter()).compile(package)

    def test_compile_rejects_unexplained_compression_ratio(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = create_package(Path(directory))
            config_path = package / "book.json"
            config = json.loads(config_path.read_text(encoding="utf-8"))
            config["chapters"][0]["source_words"] = 1000
            config_path.write_text(
                json.dumps(config, indent=2) + "\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ImporterError, "outside 18.5%-20.5%"):
                BookPackageCompiler(FakeMarkdownConverter()).compile(package)


if __name__ == "__main__":
    unittest.main()
