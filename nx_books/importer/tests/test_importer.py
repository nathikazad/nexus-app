from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from importer.book_importer import BookImporter, BookPackageCompiler
from importer.tests.helpers import (
    FakeBackupRunner,
    FakeKgqlClient,
    FakeMarkdownConverter,
    create_package,
)


class BookImporterTest(unittest.TestCase):
    def _manifest(self, directory: str) -> tuple[Path, dict]:
        package = create_package(Path(directory))
        path = BookPackageCompiler(FakeMarkdownConverter()).compile(package)
        return path, BookImporter.load_manifest(path)

    def test_dry_run_has_no_writes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            _, manifest = self._manifest(directory)
            client = FakeKgqlClient(77, "Sample Book")
            plan = BookImporter(client).plan(manifest)

            self.assertEqual(plan.chapter_count, 2)
            self.assertEqual(len(plan.create_documents), 2)
            self.assertEqual(plan.append_chapters, (1, 2))
            self.assertEqual(client.mutations, [])

    def test_payloads_use_attributes_and_nested_relations(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            _, manifest = self._manifest(directory)
            chapter_payload = BookImporter.chapter_create_payload(
                manifest["chapters"][0]
            )
            self.assertEqual(chapter_payload["model_type"], "Document")
            self.assertNotIn("document", chapter_payload)
            self.assertEqual(
                {item["key"] for item in chapter_payload["attributes"]},
                {"document", "json_document", "pinned", "publish"},
            )

            book = FakeKgqlClient(77, "Sample Book").book
            wrapper = {
                "format": "appflowy_document",
                "document": {"type": "page", "children": []},
            }
            book_payload = BookImporter.book_update_payload(
                book, wrapper, [9001, 9002]
            )
            self.assertNotIn("model_type", book_payload)
            self.assertEqual(
                book_payload["relations"],
                [
                    {
                        "model_type": "Document",
                        "relation_name": "references_document",
                        "link": [9001, 9002],
                    }
                ],
            )

    def test_execute_imports_and_verifies_without_changing_book_metadata(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            manifest_path, manifest = self._manifest(directory)
            client = FakeKgqlClient(77, "Sample Book")
            backup = FakeBackupRunner()
            receipt = manifest_path.with_name("receipt.json")

            result = BookImporter(client, backup).execute(
                manifest, receipt
            )

            self.assertEqual(backup.calls, 1)
            self.assertEqual(len(client.documents), 2)
            self.assertEqual(client.book["tags"], {"Topic": ["People"]})
            self.assertEqual(client.book["reading_state"], "to_read")
            self.assertEqual(client.book["rank"], 4)
            self.assertEqual(result["verification"]["links"], 2)
            self.assertEqual(result["verification"]["relations"], 2)
            saved = json.loads(receipt.read_text(encoding="utf-8"))
            self.assertEqual(saved["status"], "complete")
            self.assertEqual(
                sorted(saved["chapter_ids"]),
                ["1", "2"],
            )
            book_mutation = client.mutations[-1]
            self.assertNotIn("model_type", book_mutation)
            self.assertIn("relations", book_mutation)

    def test_resume_reuses_documents_and_does_not_duplicate_links(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            manifest_path, manifest = self._manifest(directory)
            client = FakeKgqlClient(77, "Sample Book")
            backup = FakeBackupRunner()
            receipt = manifest_path.with_name("receipt.json")
            importer = BookImporter(client, backup)
            importer.execute(manifest, receipt)
            document_ids = set(client.documents)

            importer.execute(manifest, receipt, resume=True)

            self.assertEqual(set(client.documents), document_ids)
            hrefs = []
            for block in client.book["json_document"]["document"]["children"]:
                for part in (block.get("data") or {}).get("delta") or []:
                    href = (part.get("attributes") or {}).get("href")
                    if href:
                        hrefs.append(href)
            self.assertEqual(len(hrefs), 2)
            self.assertEqual(len(set(hrefs)), 2)
            self.assertEqual(len(client.book["Document"]), 2)
            self.assertEqual(backup.calls, 2)


if __name__ == "__main__":
    unittest.main()
