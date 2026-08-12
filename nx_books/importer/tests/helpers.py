from __future__ import annotations

import copy
import json
from pathlib import Path
import re
from typing import Any, Mapping, Sequence

from importer.book_importer import BackupResult


class FakeMarkdownConverter:
    """Small deterministic converter used instead of Flutter in unit tests."""

    def convert(self, markdown_directory: Path) -> None:
        for path in sorted(markdown_directory.glob("*.md")):
            blocks = self._blocks(path.read_text(encoding="utf-8"))
            payload = {
                "format": "appflowy_document",
                "document": {"type": "page", "children": blocks},
            }
            path.with_suffix(".appflowy.json").write_text(
                json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )

    @staticmethod
    def _blocks(markdown: str) -> list[dict[str, Any]]:
        blocks: list[dict[str, Any]] = []
        paragraphs: list[str] = []

        def flush() -> None:
            if not paragraphs:
                return
            blocks.append(
                {
                    "type": "paragraph",
                    "data": {
                        "delta": [
                            {"insert": " ".join(part.strip() for part in paragraphs)}
                        ]
                    },
                }
            )
            paragraphs.clear()

        for line in markdown.strip().splitlines():
            heading = re.match(r"^(#{1,6})\s+(.+)$", line)
            if heading:
                flush()
                blocks.append(
                    {
                        "type": "heading",
                        "data": {
                            "level": len(heading.group(1)),
                            "delta": [{"insert": heading.group(2).strip()}],
                        },
                    }
                )
            elif not line.strip():
                flush()
            else:
                paragraphs.append(line)
        flush()
        return blocks


class FakeBackupRunner:
    def __init__(self) -> None:
        self.calls = 0

    def create(self) -> BackupResult:
        self.calls += 1
        return BackupResult(
            path="/backups/test.dump",
            checksum_path="/backups/test.dump.sha256",
            sha256="a" * 64,
            size_bytes=123,
        )


class FakeKgqlClient:
    def __init__(self, book_id: int, book_name: str) -> None:
        self.book = {
            "id": book_id,
            "name": book_name,
            "description": None,
            "document": None,
            "json_document": None,
            "publish": None,
            "pinned": None,
            "tags": {"Topic": ["People"]},
            "reading_state": "to_read",
            "rank": 4,
            "current_chapter": None,
            "total_chapters": None,
            "word_count": None,
            "author": "Test Author",
            "link": None,
            "Book Chapter": [],
        }
        self.chapters: dict[int, dict[str, Any]] = {}
        self.next_id = 9001
        self.mutations: list[dict[str, Any]] = []

    def get_model_type(self, model_type: str) -> Any:
        if model_type == "Book":
            return [
                {
                    "name": "Book",
                    "relations": [
                        {
                            "relation_name": "book_book_chapter",
                            "target_model_type": "Book Chapter",
                        }
                    ],
                }
            ]
        if model_type == "Book Chapter":
            return [
                {
                    "name": "Book Chapter",
                    "attributes": [{"key": "chapter_number"}],
                }
            ]
        return []

    def get_models(
        self,
        model_type: str,
        filters: Sequence[Mapping[str, Any]],
        struct: Mapping[str, Any],
    ) -> list[dict[str, Any]]:
        del struct
        if model_type == "Book":
            models = [self.book]
        elif model_type == "Book Chapter":
            models = list(self.chapters.values())
        else:
            models = []
        for condition in filters:
            key = condition["key"]
            value = condition["value"]
            if condition["op"] != "=":
                raise AssertionError("Fake only implements equality")
            models = [row for row in models if row.get(key) == value]
        return copy.deepcopy(models)

    def set_model(self, data: Mapping[str, Any]) -> dict[str, Any]:
        payload = copy.deepcopy(dict(data))
        self.mutations.append(payload)
        model_id = payload.get("id")
        if model_id is None:
            if payload.get("model_type") != "Book Chapter":
                raise AssertionError("Fake only creates Book Chapter models")
            model_id = self.next_id
            self.next_id += 1
            row = {
                "id": model_id,
                "name": payload["name"],
                "description": payload.get("description"),
                "document": None,
                "json_document": None,
                "publish": None,
                "pinned": None,
                "tags": self._tags(payload.get("tags") or []),
            }
            self._apply_attributes(row, payload.get("attributes") or [])
            self.chapters[model_id] = row
            return {"id": model_id}
        if model_id != self.book["id"]:
            row = self.chapters[int(model_id)]
            if "description" in payload:
                row["description"] = payload["description"]
            self._apply_attributes(row, payload.get("attributes") or [])
            return {"id": model_id}
        if "model_type" in payload:
            raise AssertionError("Book update must not change model_type")
        if "description" in payload:
            self.book["description"] = payload["description"]
        self._apply_attributes(self.book, payload.get("attributes") or [])
        for relation in payload.get("relations") or []:
            if relation != {
                "model_type": "Book Chapter",
                "relation_name": "book_book_chapter",
                "link": relation["link"],
            }:
                raise AssertionError("Malformed relation payload")
            existing = {
                int(item["id"])
                for item in self.book.get("Book Chapter") or []
            }
            for linked_id in relation["link"]:
                if linked_id in existing:
                    continue
                chapter = self.chapters[int(linked_id)]
                self.book["Book Chapter"].append(
                    {
                        "id": linked_id,
                        "name": chapter["name"],
                        "description": chapter["description"],
                        "chapter_number": chapter["chapter_number"],
                    }
                )
        return {"id": model_id}

    @staticmethod
    def _apply_attributes(
        row: dict[str, Any],
        attributes: Sequence[Mapping[str, Any]],
    ) -> None:
        for attribute in attributes:
            row[str(attribute["key"])] = copy.deepcopy(attribute.get("value"))

    @staticmethod
    def _tags(values: Sequence[Mapping[str, Any]]) -> dict[str, list[str]]:
        return {
            str(item["system"]): [str(node) for node in item.get("nodes") or []]
            for item in values
        }


def create_package(root: Path, *, two_short_paragraphs: bool = False) -> Path:
    package = root / "sample-book"
    chapters = package / "chapters"
    chapters.mkdir(parents=True)
    (package / "book.json").write_text(
        json.dumps(
            {
                "schema_version": 1,
                "book": {
                    "kgql_id": 77,
                    "expected_name": "Sample Book",
                    "author": "Test Author",
                },
                "chapters": [
                    {
                        "number": 1,
                        "title": "First Ideas",
                        "file": "chapters/ch01.md",
                        "source_words": 65,
                    },
                    {
                        "number": 2,
                        "title": "Second Ideas",
                        "file": "chapters/ch02.md",
                        "source_words": 65,
                    },
                ],
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    separator = "\n\nAnother paragraph." if two_short_paragraphs else ""
    for number in (1, 2):
        (chapters / f"ch0{number}.md").write_text(
            f"""<!-- SHORT_SUMMARY -->

Chapter {number} has one concise summary paragraph.{separator}

<!-- DETAILED_SUMMARY -->

## Main Point

Chapter {number} explains its central idea with enough detail for testing.
""",
            encoding="utf-8",
        )
    return package
