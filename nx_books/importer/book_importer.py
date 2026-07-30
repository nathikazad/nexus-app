#!/usr/bin/env python3
"""Compile structured book summaries and import them through existing KGQL APIs."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime, timezone
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from typing import Any, Iterable, Mapping, Protocol, Sequence
import urllib.request
import uuid


SHORT_MARKER = "<!-- SHORT_SUMMARY -->"
DETAILED_MARKER = "<!-- DETAILED_SUMMARY -->"
APPFLOWY_FORMAT = "appflowy_document"
MANIFEST_SCHEMA_VERSION = 1
DEFAULT_GRAPHQL_URL = "http://100.108.43.37:5001/graphql"
DEFAULT_DOMAIN_ID = 1
DEFAULT_USER_ID = "1"
DEFAULT_NEXUS_MOBILE = Path("/Users/nathikazad/Projects/Nexus/mobile")
DEFAULT_FLUTTER = Path("/Users/nathikazad/development/flutter/bin/flutter")
DEFAULT_BACKUP_SCRIPT = Path(
    "/Users/nathikazad/Projects/Nexus/servers/"
    "skills/backup-nexus-db/scripts/create_backup.sh"
)
DEFAULT_BACKUP_TARGET = "nathik@100.108.43.37"


class ImporterError(RuntimeError):
    """Raised when compilation or import safety checks fail."""


def _canonical(value: Any) -> Any:
    if isinstance(value, Mapping):
        return {str(key): _canonical(value[key]) for key in sorted(value)}
    if isinstance(value, list):
        return [_canonical(item) for item in value]
    return value


def _json_text(value: Any) -> str:
    return json.dumps(
        _canonical(value),
        ensure_ascii=False,
        separators=(",", ":"),
    )


def _delta_text(block: Mapping[str, Any]) -> str:
    data = block.get("data") or {}
    return "".join(
        str(part.get("insert") or "")
        for part in data.get("delta") or []
        if isinstance(part, Mapping)
    )


def _blocks_in_order(block: Mapping[str, Any]) -> Iterable[Mapping[str, Any]]:
    for child in block.get("children") or []:
        if not isinstance(child, Mapping):
            continue
        yield child
        yield from _blocks_in_order(child)


def appflowy_plain_text(wrapper: Mapping[str, Any]) -> str:
    document = wrapper.get("document")
    if not isinstance(document, Mapping):
        raise ImporterError("AppFlowy wrapper is missing a document object")
    return "\n".join(
        text
        for text in (_delta_text(block) for block in _blocks_in_order(document))
        if text
    ).strip()


def description_excerpt(text: str) -> str:
    normalized = re.sub(r"\s+", " ", text).strip()
    return normalized if len(normalized) <= 140 else normalized[:137] + "..."


def appflowy_content_hash(
    wrapper: Mapping[str, Any],
    topic_tags: Sequence[str] = (),
) -> str:
    topics = sorted({tag.strip() for tag in topic_tags if tag.strip()})
    envelope = {
        "format": wrapper.get("format"),
        "document": wrapper.get("document"),
        "tags": {"Topic": topics} if topics else {},
    }
    return "sha256:" + hashlib.sha256(
        _json_text(envelope).encode("utf-8")
    ).hexdigest()


def disabled_publish_state(
    wrapper: Mapping[str, Any],
    topic_tags: Sequence[str] = (),
) -> dict[str, Any]:
    return {
        "enabled": False,
        "dirty": False,
        "content_hash": appflowy_content_hash(wrapper, topic_tags),
        "last_published_hash": None,
        "first_published_at": None,
        "last_published_at": None,
        "status": "draft",
        "last_error": None,
        "slug": None,
        "title": None,
    }


def publish_state_with_current_content(
    current: Any,
    wrapper: Mapping[str, Any],
    topic_tags: Sequence[str] = (),
) -> dict[str, Any]:
    if not isinstance(current, Mapping):
        return disabled_publish_state(wrapper, topic_tags)
    updated = {
        "enabled": current.get("enabled") is True,
        "dirty": current.get("dirty") is True,
        "content_hash": current.get("content_hash"),
        "last_published_hash": current.get("last_published_hash"),
        "first_published_at": current.get("first_published_at"),
        "last_published_at": current.get("last_published_at"),
        "status": current.get("status") or "draft",
        "last_error": current.get("last_error"),
        "slug": current.get("slug"),
        "title": current.get("title"),
    }
    content_hash = appflowy_content_hash(wrapper, topic_tags)
    updated["content_hash"] = content_hash
    if not updated["enabled"]:
        updated["status"] = "pending" if updated["dirty"] else "draft"
        return updated
    updated["dirty"] = content_hash != updated["last_published_hash"]
    updated["status"] = "pending" if updated["dirty"] else "published"
    updated["last_error"] = None
    return updated


def _semantic_string(value: Any) -> Any:
    if not isinstance(value, str):
        return value
    try:
        decoded = json.loads(value)
        return decoded if isinstance(decoded, str) else value
    except json.JSONDecodeError:
        try:
            return json.loads('"' + value + '"')
        except json.JSONDecodeError:
            return value


def _validate_appflowy(wrapper: Any, label: str) -> dict[str, Any]:
    if not isinstance(wrapper, dict):
        raise ImporterError(f"{label}: AppFlowy payload must be an object")
    if wrapper.get("format") != APPFLOWY_FORMAT:
        raise ImporterError(f"{label}: unexpected AppFlowy format")
    document = wrapper.get("document")
    if not isinstance(document, dict) or document.get("type") != "page":
        raise ImporterError(f"{label}: invalid AppFlowy document root")
    children = document.get("children")
    if not isinstance(children, list) or not children:
        raise ImporterError(f"{label}: AppFlowy document has no blocks")
    return wrapper


def _safe_package_path(package_dir: Path, relative: str) -> Path:
    candidate = (package_dir / relative).resolve()
    try:
        candidate.relative_to(package_dir.resolve())
    except ValueError as error:
        raise ImporterError(f"Chapter file escapes package directory: {relative}") from error
    return candidate


def _parse_chapter_markdown(text: str, label: str) -> tuple[str, str]:
    if text.count(SHORT_MARKER) != 1 or text.count(DETAILED_MARKER) != 1:
        raise ImporterError(
            f"{label}: expected exactly one {SHORT_MARKER} and {DETAILED_MARKER}"
        )
    before_short, remaining = text.split(SHORT_MARKER, 1)
    short, detailed = remaining.split(DETAILED_MARKER, 1)
    if before_short.strip():
        raise ImporterError(f"{label}: content is not allowed before {SHORT_MARKER}")
    short = short.strip()
    detailed = detailed.strip()
    if not short or not detailed:
        raise ImporterError(f"{label}: short and detailed summaries are required")
    short_paragraphs = [
        part.strip() for part in re.split(r"\n\s*\n", short) if part.strip()
    ]
    if len(short_paragraphs) != 1:
        raise ImporterError(f"{label}: short summary must be exactly one paragraph")
    if re.search(r"(?m)^\s{0,3}#{1,6}\s+", short):
        raise ImporterError(f"{label}: short summary cannot contain headings")
    if re.search(r"(?m)^\s*(?:[-*+]|\d+[.)])\s+", short):
        raise ImporterError(f"{label}: short summary cannot contain lists")
    if re.search(r"(?m)^\s{0,3}#\s+", detailed):
        raise ImporterError(
            f"{label}: detailed summary must not contain an H1; title comes from book.json"
        )
    return re.sub(r"\s*\n\s*", " ", short).strip(), detailed


class MarkdownConverter(Protocol):
    def convert(self, markdown_directory: Path) -> None:
        """Create .appflowy.json companions for all Markdown files."""


_DART_CONVERTER_TEST = r"""
import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('compile book summary Markdown to AppFlowy JSON', () {
    final value = Platform.environment['NX_BOOK_IMPORT_MARKDOWN_DIR'];
    if (value == null || value.isEmpty) {
      throw StateError('NX_BOOK_IMPORT_MARKDOWN_DIR is required');
    }
    final directory = Directory(value);
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.md'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) throw StateError('No Markdown files found in $value');
    const encoder = JsonEncoder.withIndent('  ');
    for (final file in files) {
      final document = markdownToDocument(file.readAsStringSync());
      final documentJson = document.toJson()['document'];
      if (documentJson is! Map) {
        throw StateError('Invalid document generated for ${file.path}');
      }
      final payload = {
        'format': 'appflowy_document',
        'document': documentJson,
      };
      final output = file.path.replaceFirst(RegExp(r'\.md$'), '.appflowy.json');
      File(output).writeAsStringSync('${encoder.convert(payload)}\n');
      final decoded = jsonDecode(File(output).readAsStringSync());
      final verified = Document.fromJson({
        'document': Map<String, dynamic>.from(decoded['document'] as Map),
      });
      if (verified.root.type != 'page' || verified.root.children.isEmpty) {
        throw StateError('Round-trip verification failed for $output');
      }
      verified.dispose();
      document.dispose();
    }
  });
}
"""


class FlutterMarkdownConverter:
    def __init__(
        self,
        nexus_mobile: Path = DEFAULT_NEXUS_MOBILE,
        flutter: Path | None = None,
    ) -> None:
        self.nexus_mobile = nexus_mobile.expanduser().resolve()
        selected_flutter = flutter or Path(
            os.environ.get(
                "FLUTTER_BIN",
                shutil.which("flutter") or str(DEFAULT_FLUTTER),
            )
        )
        self.flutter = selected_flutter.expanduser().resolve()

    def convert(self, markdown_directory: Path) -> None:
        nx_notes = self.nexus_mobile / "nx_notes"
        converter = (
            self.nexus_mobile
            / "appflowy-editor/lib/src/plugins/markdown/document_markdown.dart"
        )
        if not (nx_notes / "pubspec.yaml").is_file():
            raise ImporterError(f"nx_notes package not found: {nx_notes}")
        if not converter.is_file():
            raise ImporterError(f"AppFlowy Markdown converter not found: {converter}")
        if not self.flutter.is_file():
            raise ImporterError(f"Flutter executable not found: {self.flutter}")
        test_dir = nx_notes / "test"
        test_dir.mkdir(parents=True, exist_ok=True)
        test_path = test_dir / f"_nx_books_import_{uuid.uuid4().hex}_test.dart"
        test_path.write_text(_DART_CONVERTER_TEST, encoding="utf-8")
        environment = os.environ.copy()
        environment["NX_BOOK_IMPORT_MARKDOWN_DIR"] = str(markdown_directory)
        try:
            completed = subprocess.run(
                [
                    str(self.flutter),
                    "test",
                    str(test_path.relative_to(nx_notes)),
                    "--reporter",
                    "expanded",
                ],
                cwd=nx_notes,
                env=environment,
                text=True,
                check=False,
            )
            if completed.returncode:
                raise ImporterError(
                    f"AppFlowy conversion failed with exit code {completed.returncode}"
                )
        finally:
            test_path.unlink(missing_ok=True)


class BookPackageCompiler:
    def __init__(self, converter: MarkdownConverter) -> None:
        self.converter = converter

    def compile(
        self,
        package_directory: Path,
        output_directory: Path | None = None,
    ) -> Path:
        package_dir = package_directory.expanduser().resolve()
        config_path = package_dir / "book.json"
        if not config_path.is_file():
            raise ImporterError(f"book.json not found: {config_path}")
        try:
            config = json.loads(config_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            raise ImporterError(f"Invalid book.json: {error}") from error
        book, chapters = self._validate_config(config)
        build_dir = (
            output_directory.expanduser().resolve()
            if output_directory
            else package_dir / "build"
        )
        markdown_dir = build_dir / "markdown"
        markdown_dir.mkdir(parents=True, exist_ok=True)
        prepared: list[dict[str, Any]] = []
        for chapter in chapters:
            number = chapter["number"]
            title = chapter["title"]
            name = f"Chapter {number}: {title}"
            source_path = _safe_package_path(package_dir, chapter["file"])
            if not source_path.is_file():
                raise ImporterError(f"Chapter source not found: {source_path}")
            short, detailed = _parse_chapter_markdown(
                source_path.read_text(encoding="utf-8"),
                str(source_path),
            )
            detailed_path = markdown_dir / f"detailed-summary-ch{number}.md"
            short_path = markdown_dir / f"short-summary-ch{number}.md"
            detailed_path.write_text(f"# {name}\n\n{detailed}\n", encoding="utf-8")
            short_path.write_text(f"# {name}\n\n{short}\n", encoding="utf-8")
            prepared.append(
                {
                    **chapter,
                    "document_name": name,
                    "source_path": str(source_path.relative_to(package_dir)),
                    "short_summary": short,
                    "detailed_markdown": detailed_path,
                    "short_markdown": short_path,
                }
            )
        self.converter.convert(markdown_dir)
        compiled_chapters = [
            self._compile_chapter(item) for item in prepared
        ]
        manifest = {
            "schema_version": MANIFEST_SCHEMA_VERSION,
            "book": book,
            "chapters": compiled_chapters,
        }
        build_dir.mkdir(parents=True, exist_ok=True)
        manifest_path = build_dir / "kgql-import.json"
        manifest_path.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        return manifest_path

    @staticmethod
    def _validate_config(
        config: Any,
    ) -> tuple[dict[str, Any], list[dict[str, Any]]]:
        if not isinstance(config, dict) or config.get("schema_version") != 1:
            raise ImporterError("book.json schema_version must be 1")
        raw_book = config.get("book")
        raw_chapters = config.get("chapters")
        if not isinstance(raw_book, dict) or not isinstance(raw_chapters, list):
            raise ImporterError("book.json requires book and chapters")
        book_id = raw_book.get("kgql_id")
        expected_name = str(raw_book.get("expected_name") or "").strip()
        if not isinstance(book_id, int) or book_id <= 0 or not expected_name:
            raise ImporterError("book.kgql_id and book.expected_name are required")
        book = {
            "kgql_id": book_id,
            "expected_name": expected_name,
            "author": str(raw_book.get("author") or "").strip(),
        }
        chapters: list[dict[str, Any]] = []
        seen_numbers: set[int] = set()
        for raw in raw_chapters:
            if not isinstance(raw, dict):
                raise ImporterError("Each chapter entry must be an object")
            number = raw.get("number")
            title = str(raw.get("title") or "").strip()
            file = str(raw.get("file") or "").strip()
            if (
                not isinstance(number, int)
                or number <= 0
                or number in seen_numbers
                or not title
                or not file
            ):
                raise ImporterError(f"Invalid chapter entry: {raw!r}")
            seen_numbers.add(number)
            chapter = {"number": number, "title": title, "file": file}
            source_words = raw.get("source_words")
            if source_words is not None:
                if not isinstance(source_words, int) or source_words <= 0:
                    raise ImporterError(
                        f"Chapter {number}: source_words must be a positive integer"
                    )
                chapter["source_words"] = source_words
            compression_note = str(raw.get("compression_note") or "").strip()
            if compression_note:
                chapter["compression_note"] = compression_note
            chapters.append(chapter)
        chapters.sort(key=lambda item: item["number"])
        expected_numbers = list(
            range(chapters[0]["number"], chapters[-1]["number"] + 1)
        ) if chapters else []
        actual_numbers = [item["number"] for item in chapters]
        if not chapters or actual_numbers != expected_numbers:
            raise ImporterError(
                f"Chapter numbers must be contiguous: {actual_numbers}"
            )
        return book, chapters

    @staticmethod
    def _compile_chapter(chapter: Mapping[str, Any]) -> dict[str, Any]:
        name = chapter["document_name"]
        detailed_path = Path(chapter["detailed_markdown"])
        short_path = Path(chapter["short_markdown"])
        detailed = _validate_appflowy(
            json.loads(
                detailed_path.with_suffix(".appflowy.json").read_text(
                    encoding="utf-8"
                )
            ),
            name,
        )
        short = _validate_appflowy(
            json.loads(
                short_path.with_suffix(".appflowy.json").read_text(
                    encoding="utf-8"
                )
            ),
            f"{name} short summary",
        )
        detailed_children = detailed["document"]["children"]
        if (
            detailed_children[0].get("type") != "heading"
            or detailed_children[0].get("data", {}).get("level") != 1
            or _delta_text(detailed_children[0]) != name
        ):
            raise ImporterError(f"{name}: detailed AppFlowy H1 mismatch")
        short_children = short["document"]["children"]
        if (
            len(short_children) != 2
            or _delta_text(short_children[0]) != name
            or short_children[1].get("type") != "paragraph"
        ):
            raise ImporterError(f"{name}: short AppFlowy structure mismatch")
        stored = copy.deepcopy(detailed)
        stored["document"]["children"] = stored["document"]["children"][1:]
        plain = appflowy_plain_text(stored)
        summary_words = len(
            re.findall(
                r"\b[\w’'-]+\b",
                detailed_path.read_text(encoding="utf-8").split("\n", 2)[-1],
            )
        )
        source_words = chapter.get("source_words")
        ratio = (
            round(summary_words / source_words, 6)
            if isinstance(source_words, int)
            else None
        )
        compression_note = chapter.get("compression_note")
        if (
            ratio is not None
            and not 0.185 <= ratio <= 0.205
            and not compression_note
        ):
            raise ImporterError(
                f"{name}: detailed summary ratio {ratio:.1%} is outside "
                "18.5%-20.5%; add compression_note only for an intentional exception"
            )
        return {
            "number": chapter["number"],
            "title": chapter["title"],
            "document_name": name,
            "source_file": chapter["source_path"],
            "source_words": source_words,
            "summary_words": summary_words,
            "compression_ratio": ratio,
            "compression_note": compression_note,
            "short_summary": chapter["short_summary"],
            "short_appflowy_block": copy.deepcopy(short_children[1]),
            "detailed_appflowy_document": detailed,
            "kgql_json_document": stored,
            "plain_text": plain,
            "description": description_excerpt(plain),
            "publish": disabled_publish_state(stored),
        }


class KgqlClient(Protocol):
    def get_model_type(self, model_type: str) -> Any:
        ...

    def get_models(
        self,
        model_type: str,
        filters: Sequence[Mapping[str, Any]],
        struct: Mapping[str, Any],
    ) -> list[dict[str, Any]]:
        ...

    def set_model(self, data: Mapping[str, Any]) -> dict[str, Any]:
        ...


class GraphQLKgqlClient:
    GET_MODELS = """
    query GetKgqlModels($filter: JSON, $struct: JSON, $domainId: Int) {
      getKgqlModels(filter: $filter, struct: $struct, domainId: $domainId)
    }
    """
    GET_MODEL_TYPE = """
    query GetKgqlModelType($input: JSON!) {
      getKgqlModelType(input: $input)
    }
    """
    MUTATE_DOCUMENT = """
    mutation MutateDocument(
      $data: JSON!
      $clientUpdatedAt: String
      $domainId: Int
    ) {
      mutateDocument(
        data: $data
        clientUpdatedAt: $clientUpdatedAt
        domainId: $domainId
      )
    }
    """

    def __init__(
        self,
        url: str = DEFAULT_GRAPHQL_URL,
        user_id: str = DEFAULT_USER_ID,
        domain_id: int = DEFAULT_DOMAIN_ID,
        timeout: int = 30,
    ) -> None:
        self.url = url
        self.user_id = user_id
        self.domain_id = domain_id
        self.timeout = timeout

    def _request(self, query: str, variables: Mapping[str, Any]) -> dict[str, Any]:
        request = urllib.request.Request(
            self.url,
            json.dumps(
                {"query": query, "variables": variables},
                ensure_ascii=False,
            ).encode("utf-8"),
            {"content-type": "application/json", "x-user-id": self.user_id},
        )
        with urllib.request.urlopen(request, timeout=self.timeout) as response:
            result = json.load(response)
        if result.get("errors"):
            raise ImporterError(
                "GraphQL error: "
                + json.dumps(result["errors"], ensure_ascii=False)
            )
        return result

    def get_model_type(self, model_type: str) -> Any:
        result = self._request(
            self.GET_MODEL_TYPE,
            {"input": {"model_types": [model_type]}},
        )
        return result["data"]["getKgqlModelType"]

    def get_models(
        self,
        model_type: str,
        filters: Sequence[Mapping[str, Any]],
        struct: Mapping[str, Any],
    ) -> list[dict[str, Any]]:
        result = self._request(
            self.GET_MODELS,
            {
                "filter": {"model_type": model_type, "filters": list(filters)},
                "struct": dict(struct),
                "domainId": self.domain_id,
            },
        )
        rows = result["data"]["getKgqlModels"]
        if isinstance(rows, str):
            rows = json.loads(rows)
        return rows or []

    def set_model(self, data: Mapping[str, Any]) -> dict[str, Any]:
        payload = dict(data)
        client_updated_at = (
            datetime.now(timezone.utc).isoformat()
            if payload.get("id") is not None
            else None
        )
        result = self._request(
            self.MUTATE_DOCUMENT,
            {
                "data": payload,
                "clientUpdatedAt": client_updated_at,
                "domainId": self.domain_id,
            },
        )
        value = result["data"]["mutateDocument"]
        return json.loads(value) if isinstance(value, str) else value


@dataclass(frozen=True)
class BackupResult:
    path: str
    checksum_path: str
    sha256: str
    size_bytes: int | None = None


class BackupRunner(Protocol):
    def create(self) -> BackupResult:
        ...


class SubprocessBackupRunner:
    def __init__(
        self,
        script: Path = DEFAULT_BACKUP_SCRIPT,
        target: str = DEFAULT_BACKUP_TARGET,
        label: str = "before-book-summary-import",
    ) -> None:
        self.script = script.expanduser().resolve()
        self.target = target
        self.label = label

    def create(self) -> BackupResult:
        if not self.script.is_file():
            raise ImporterError(f"Backup script not found: {self.script}")
        completed = subprocess.run(
            [
                str(self.script),
                "--target",
                self.target,
                "--label",
                self.label,
            ],
            text=True,
            capture_output=True,
            check=False,
        )
        output = completed.stdout + completed.stderr
        if (
            completed.returncode
            or "status=ok" not in output
            or "archive_validation=pg_restore_list_ok" not in output
        ):
            raise ImporterError(f"Production backup failed:\n{output.strip()}")
        values = dict(
            line.split("=", 1)
            for line in output.splitlines()
            if "=" in line
        )
        return BackupResult(
            path=values["path"],
            checksum_path=values["checksum_path"],
            sha256=values["sha256"],
            size_bytes=(
                int(values["size_bytes"]) if values.get("size_bytes") else None
            ),
        )


@dataclass(frozen=True)
class ImportPlan:
    book_id: int
    book_name: str
    chapter_count: int
    create_documents: tuple[str, ...]
    reuse_documents: tuple[str, ...]
    append_chapters: tuple[int, ...]
    relation_count: int


_DOCUMENT_STRUCT = {
    "id": True,
    "name": True,
    "description": True,
    "document": True,
    "json_document": True,
    "publish": True,
    "pinned": True,
    "tags": True,
}
_BOOK_STRUCT = {
    **_DOCUMENT_STRUCT,
    "reading_state": True,
    "rank": True,
    "current_chapter": True,
    "total_chapters": True,
    "word_count": True,
    "author": True,
    "link": True,
    "Document": {"id": True, "name": True, "description": True},
}


def _attributes(values: Mapping[str, Any]) -> list[dict[str, Any]]:
    return [{"key": key, "value": value} for key, value in values.items()]


def _hrefs(wrapper: Mapping[str, Any]) -> list[str]:
    found: list[str] = []
    document = wrapper.get("document")
    if not isinstance(document, Mapping):
        return found
    for block in _blocks_in_order(document):
        for part in (block.get("data") or {}).get("delta") or []:
            if not isinstance(part, Mapping):
                continue
            attributes = part.get("attributes") or {}
            if isinstance(attributes, Mapping) and attributes.get("href"):
                found.append(str(attributes["href"]))
    return found


class BookImporter:
    def __init__(
        self,
        client: KgqlClient,
        backup_runner: BackupRunner | None = None,
    ) -> None:
        self.client = client
        self.backup_runner = backup_runner

    @staticmethod
    def load_manifest(path: Path) -> dict[str, Any]:
        try:
            manifest = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise ImporterError(f"Cannot load import manifest: {error}") from error
        if (
            not isinstance(manifest, dict)
            or manifest.get("schema_version") != MANIFEST_SCHEMA_VERSION
            or not isinstance(manifest.get("book"), dict)
            or not isinstance(manifest.get("chapters"), list)
        ):
            raise ImporterError("Unsupported or malformed import manifest")
        return manifest

    def plan(self, manifest: Mapping[str, Any]) -> ImportPlan:
        schema = self.client.get_model_type("Book")
        if not isinstance(schema, list) or not any(
            isinstance(item, Mapping) and item.get("name") == "Book"
            for item in schema
        ):
            raise ImporterError("KGQL Book model type was not found")
        book = self._get_book(manifest)
        related_ids = {
            int(row["id"]) for row in book.get("Document") or [] if row.get("id")
        }
        wrapper = book.get("json_document") or {
            "format": APPFLOWY_FORMAT,
            "document": {"type": "page", "children": []},
        }
        hrefs = set(_hrefs(wrapper))
        creates: list[str] = []
        reuses: list[str] = []
        append: list[int] = []
        target_relation_count = 0
        for chapter in manifest["chapters"]:
            rows = self._exact_documents(chapter["document_name"])
            if len(rows) > 1:
                raise ImporterError(
                    f"Duplicate target Document: {chapter['document_name']}"
                )
            if rows:
                self._verify_document_row(rows[0], chapter)
                reuses.append(chapter["document_name"])
                model_id = int(rows[0]["id"])
                if model_id in related_ids:
                    target_relation_count += 1
                href = f"kgql://Document/{model_id}"
                if href not in hrefs:
                    append.append(int(chapter["number"]))
            else:
                creates.append(chapter["document_name"])
                append.append(int(chapter["number"]))
        return ImportPlan(
            book_id=int(manifest["book"]["kgql_id"]),
            book_name=book["name"],
            chapter_count=len(manifest["chapters"]),
            create_documents=tuple(creates),
            reuse_documents=tuple(reuses),
            append_chapters=tuple(append),
            relation_count=target_relation_count,
        )

    def execute(
        self,
        manifest: Mapping[str, Any],
        receipt_path: Path,
        *,
        resume: bool = False,
    ) -> dict[str, Any]:
        initial_plan = self.plan(manifest)
        if self.backup_runner is None:
            raise ImporterError("Execute requires a production backup runner")
        backup = self.backup_runner.create()
        receipt = self._load_receipt(receipt_path) if resume else None
        ids: dict[int, int] = {}
        if receipt:
            ids.update(
                {
                    int(number): int(model_id)
                    for number, model_id in receipt.get("chapter_ids", {}).items()
                }
            )
        for chapter in manifest["chapters"]:
            number = int(chapter["number"])
            model_id = ids.get(number)
            if model_id is not None:
                row = self._document_by_id(model_id)
                self._verify_document_row(row, chapter)
                continue
            rows = self._exact_documents(chapter["document_name"])
            if rows:
                row = rows[0]
                self._verify_document_row(row, chapter)
                model_id = int(row["id"])
            else:
                result = self.client.set_model(
                    self.chapter_create_payload(chapter)
                )
                model_id = int(result["id"])
                row = self._document_by_id(model_id)
                self._verify_document_row(row, chapter)
            ids[number] = model_id
            self._write_receipt(
                receipt_path,
                manifest,
                ids,
                backup,
                status="documents_in_progress",
            )
        self._update_book(manifest, ids, resume=resume)
        verification = self.verify(manifest, ids)
        final_receipt = self._write_receipt(
            receipt_path,
            manifest,
            ids,
            backup,
            status="complete",
            verification=verification,
        )
        return {
            "plan": asdict(initial_plan),
            "receipt": final_receipt,
            "verification": verification,
        }

    @staticmethod
    def chapter_create_payload(chapter: Mapping[str, Any]) -> dict[str, Any]:
        return {
            "model_type": "Document",
            "name": chapter["document_name"],
            "description": chapter["description"],
            "attributes": _attributes(
                {
                    "document": chapter["plain_text"],
                    "json_document": chapter["kgql_json_document"],
                    "pinned": False,
                    "publish": chapter["publish"],
                }
            ),
            "tags": [{"system": "Status", "nodes": ["Draft"]}],
        }

    @staticmethod
    def book_update_payload(
        book: Mapping[str, Any],
        wrapper: Mapping[str, Any],
        chapter_ids: Sequence[int],
    ) -> dict[str, Any]:
        plain = appflowy_plain_text(wrapper)
        topics = (book.get("tags") or {}).get("Topic") or []
        return {
            "id": int(book["id"]),
            "description": description_excerpt(plain),
            "attributes": _attributes(
                {
                    "document": plain,
                    "json_document": wrapper,
                    "pinned": (
                        False if book.get("pinned") is None else book["pinned"]
                    ),
                    "publish": publish_state_with_current_content(
                        book.get("publish"),
                        wrapper,
                        topics,
                    ),
                }
            ),
            "relations": [
                {
                    "model_type": "Document",
                    "relation_name": "references_document",
                    "link": list(chapter_ids),
                }
            ],
        }

    def verify(
        self,
        manifest: Mapping[str, Any],
        ids: Mapping[int, int],
    ) -> dict[str, Any]:
        for chapter in manifest["chapters"]:
            row = self._document_by_id(ids[int(chapter["number"])])
            self._verify_document_row(row, chapter)
        book = self._get_book(manifest)
        wrapper = book.get("json_document")
        if not isinstance(wrapper, Mapping):
            raise ImporterError("Book has no AppFlowy overview after import")
        href_list = _hrefs(wrapper)
        children = wrapper["document"].get("children") or []
        for chapter in manifest["chapters"]:
            number = int(chapter["number"])
            model_id = ids[number]
            href = f"kgql://Document/{model_id}"
            if href_list.count(href) != 1:
                raise ImporterError(
                    f"Book link count for Chapter {number} is not one"
                )
            self._verify_overview_pair(children, chapter, href)
        relation_ids = {
            int(item["id"]) for item in book.get("Document") or []
        }
        if not set(ids.values()).issubset(relation_ids):
            raise ImporterError("Book references_document relations are incomplete")
        plain = appflowy_plain_text(wrapper)
        if _semantic_string(book.get("document")) != plain:
            raise ImporterError("Book plain-text mirror does not match AppFlowy")
        if book.get("description") != description_excerpt(plain):
            raise ImporterError("Book description excerpt does not match")
        topics = (book.get("tags") or {}).get("Topic") or []
        publish = book.get("publish") or {}
        if publish.get("content_hash") != appflowy_content_hash(wrapper, topics):
            raise ImporterError("Book publish hash does not match content")
        return {
            "book_id": int(book["id"]),
            "chapter_ids": {str(key): value for key, value in sorted(ids.items())},
            "links": len(ids),
            "relations": len(set(ids.values()).intersection(relation_ids)),
        }

    def _get_book(self, manifest: Mapping[str, Any]) -> dict[str, Any]:
        book_id = int(manifest["book"]["kgql_id"])
        rows = self.client.get_models(
            "Book",
            [{"key": "id", "op": "=", "value": book_id}],
            _BOOK_STRUCT,
        )
        if len(rows) != 1:
            raise ImporterError(f"Book {book_id} was not found uniquely")
        book = rows[0]
        if book.get("name") != manifest["book"]["expected_name"]:
            raise ImporterError(
                f"Book {book_id} name changed: {book.get('name')!r}"
            )
        return book

    def _exact_documents(self, name: str) -> list[dict[str, Any]]:
        return self.client.get_models(
            "Document",
            [{"key": "name", "op": "=", "value": name}],
            _DOCUMENT_STRUCT,
        )

    def _document_by_id(self, model_id: int) -> dict[str, Any]:
        rows = self.client.get_models(
            "Document",
            [{"key": "id", "op": "=", "value": model_id}],
            _DOCUMENT_STRUCT,
        )
        if len(rows) != 1:
            raise ImporterError(f"Document {model_id} was not found uniquely")
        return rows[0]

    @staticmethod
    def _verify_document_row(
        row: Mapping[str, Any],
        chapter: Mapping[str, Any],
    ) -> None:
        if row.get("name") != chapter["document_name"]:
            raise ImporterError("Chapter Document name mismatch")
        if _canonical(row.get("json_document")) != _canonical(
            chapter["kgql_json_document"]
        ):
            raise ImporterError(
                f"{chapter['document_name']}: AppFlowy body mismatch"
            )
        children = (row.get("json_document") or {}).get("document", {}).get(
            "children", []
        )
        if children and _delta_text(children[0]) == chapter["document_name"]:
            raise ImporterError(
                f"{chapter['document_name']}: duplicated H1 in KGQL body"
            )
        if _semantic_string(row.get("document")) != chapter["plain_text"]:
            raise ImporterError(
                f"{chapter['document_name']}: plain-text mirror mismatch"
            )
        if row.get("description") != chapter["description"]:
            raise ImporterError(
                f"{chapter['document_name']}: description mismatch"
            )
        if row.get("tags") != {"Status": ["Draft"]}:
            raise ImporterError(f"{chapter['document_name']}: Status is not Draft")
        if row.get("pinned") is not False:
            raise ImporterError(f"{chapter['document_name']}: pinned must be false")
        publish = row.get("publish") or {}
        if publish.get("content_hash") != chapter["publish"]["content_hash"]:
            raise ImporterError(
                f"{chapter['document_name']}: publish hash mismatch"
            )
        if (
            publish.get("enabled") is not False
            or publish.get("dirty") is not False
            or publish.get("status") != "draft"
        ):
            raise ImporterError(
                f"{chapter['document_name']}: publish state is not a clean draft"
            )

    def _update_book(
        self,
        manifest: Mapping[str, Any],
        ids: Mapping[int, int],
        *,
        resume: bool,
    ) -> None:
        book = self._get_book(manifest)
        wrapper = copy.deepcopy(book.get("json_document"))
        if wrapper is None:
            wrapper = {
                "format": APPFLOWY_FORMAT,
                "document": {"type": "page", "children": []},
            }
        _validate_appflowy_or_empty(wrapper, "Book overview")
        existing_hrefs = _hrefs(wrapper)
        target_hrefs = {
            int(chapter["number"]): (
                f"kgql://Document/{ids[int(chapter['number'])]}"
            )
            for chapter in manifest["chapters"]
        }
        present = {
            number for number, href in target_hrefs.items() if href in existing_hrefs
        }
        if present and len(present) != len(target_hrefs) and not resume:
            raise ImporterError(
                "Book contains a partial target import; rerun with --resume"
            )
        children = wrapper["document"].setdefault("children", [])
        for chapter in manifest["chapters"]:
            number = int(chapter["number"])
            href = target_hrefs[number]
            if number in present:
                self._verify_overview_pair(children, chapter, href)
                continue
            children.extend(
                [
                    {
                        "type": "heading",
                        "data": {
                            "level": 3,
                            "delta": [
                                {
                                    "insert": f"Chapter {number}",
                                    "attributes": {"href": href},
                                },
                                {"insert": f": {chapter['title']}"},
                            ],
                        },
                    },
                    copy.deepcopy(chapter["short_appflowy_block"]),
                ]
            )
        payload = self.book_update_payload(
            book,
            wrapper,
            [ids[int(chapter["number"])] for chapter in manifest["chapters"]],
        )
        self.client.set_model(payload)
        updated = self._get_book(manifest)
        preserved_fields = (
            "name",
            "tags",
            "reading_state",
            "rank",
            "current_chapter",
            "total_chapters",
            "word_count",
            "author",
            "link",
        )
        for field in preserved_fields:
            if _canonical(updated.get(field)) != _canonical(book.get(field)):
                raise ImporterError(f"Book metadata changed unexpectedly: {field}")
        before_view_state = (
            book.get("json_document") or {}
        ).get("view_state")
        after_view_state = (
            updated.get("json_document") or {}
        ).get("view_state")
        if _canonical(after_view_state) != _canonical(before_view_state):
            raise ImporterError("Book view_state changed unexpectedly")

    @staticmethod
    def _verify_overview_pair(
        children: Sequence[Mapping[str, Any]],
        chapter: Mapping[str, Any],
        href: str,
    ) -> None:
        matches = []
        for index, block in enumerate(children):
            if block.get("type") != "heading":
                continue
            parts = (block.get("data") or {}).get("delta") or []
            if any(
                isinstance(part, Mapping)
                and (part.get("attributes") or {}).get("href") == href
                for part in parts
            ):
                matches.append(index)
        if len(matches) != 1:
            raise ImporterError(
                f"Overview heading count mismatch for Chapter {chapter['number']}"
            )
        index = matches[0]
        if index + 1 >= len(children):
            raise ImporterError("Overview heading has no short-summary paragraph")
        heading = children[index]
        expected_heading = [
            {
                "insert": f"Chapter {chapter['number']}",
                "attributes": {"href": href},
            },
            {"insert": f": {chapter['title']}"},
        ]
        if (heading.get("data") or {}).get("delta") != expected_heading:
            raise ImporterError("Overview heading text or link mismatch")
        if _canonical(children[index + 1]) != _canonical(
            chapter["short_appflowy_block"]
        ):
            raise ImporterError("Overview short-summary paragraph mismatch")

    @staticmethod
    def _load_receipt(path: Path) -> dict[str, Any] | None:
        if not path.is_file():
            return None
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            raise ImporterError(f"Invalid resume receipt: {error}") from error

    @staticmethod
    def _write_receipt(
        path: Path,
        manifest: Mapping[str, Any],
        ids: Mapping[int, int],
        backup: BackupResult,
        *,
        status: str,
        verification: Mapping[str, Any] | None = None,
    ) -> dict[str, Any]:
        receipt = {
            "schema_version": 1,
            "status": status,
            "updated_at": datetime.now(timezone.utc).isoformat(),
            "book_id": int(manifest["book"]["kgql_id"]),
            "chapter_ids": {
                str(key): value for key, value in sorted(ids.items())
            },
            "backup": asdict(backup),
            "verification": dict(verification or {}),
        }
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(receipt, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        return receipt


def _validate_appflowy_or_empty(wrapper: Any, label: str) -> None:
    if not isinstance(wrapper, dict) or wrapper.get("format") != APPFLOWY_FORMAT:
        raise ImporterError(f"{label}: invalid AppFlowy wrapper")
    document = wrapper.get("document")
    if not isinstance(document, dict) or document.get("type") != "page":
        raise ImporterError(f"{label}: invalid page root")
    if not isinstance(document.get("children"), list):
        raise ImporterError(f"{label}: children must be a list")
