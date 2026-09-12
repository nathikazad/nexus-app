"""Generation provenance and AppFlowy enrichment, independent of KGQL transport."""
from __future__ import annotations

import copy
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
from typing import Any
from urllib.parse import urlsplit


class SourceError(ValueError):
    pass


def read_package_json(root: Path, relative: str) -> Any:
    if not isinstance(relative, str) or not relative or Path(relative).is_absolute():
        raise SourceError("Source metadata requires a relative package path")
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise SourceError("Source metadata path escapes package")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise SourceError(f"Cannot read source metadata {relative}: {error}") from error


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_reference(value: Any) -> dict:
    if not isinstance(value, dict):
        raise SourceError("book_source must be an object")
    resource = value.get("resource")
    if (value.get("version") != 1 or type(value.get("book_id")) is not int
            or value["book_id"] <= 0
            or not isinstance(value.get("sha256"), str)
            or not re.fullmatch(r"[a-f0-9]{64}", value["sha256"])
            or not isinstance(resource, str) or not resource
            or any(p in ("", ".", "..") for p in resource.split("/"))
            or any(c in resource for c in "\\?#") or urlsplit(resource).scheme):
        raise SourceError("Invalid book_source identity, hash or EPUB resource")
    fragment, quote = value.get("fragment"), value.get("quote")
    if fragment is not None and (not isinstance(fragment, str) or not fragment.strip()):
        raise SourceError("Invalid EPUB fragment")
    if quote is not None:
        if (not isinstance(quote, dict) or not isinstance(quote.get("exact"), str)
                or not quote["exact"].strip()
                or any(k in quote and not isinstance(quote[k], str) for k in ("prefix", "suffix"))):
            raise SourceError("Invalid EPUB quote")
    if fragment is None and quote is None:
        raise SourceError("EPUB source needs a fragment or exact quote")
    return value


def load_catalog(root: Path, relative: str, epub: Path | None) -> dict:
    catalog = read_package_json(root, relative)
    if (not isinstance(catalog, dict) or catalog.get("schema_version") != 1
            or catalog.get("format") != "epub" or not isinstance(catalog.get("anchors"), dict)):
        raise SourceError("Invalid EPUB source catalog")
    if epub is None or not epub.is_file():
        raise SourceError("Linked summaries require --epub pointing to the original EPUB")
    if file_hash(epub) != catalog.get("sha256"):
        raise SourceError("Source catalog hash does not match the supplied EPUB")
    for anchor in catalog["anchors"].values():
        if not isinstance(anchor, dict) or set(anchor) - {"resource", "fragment", "quote"}:
            raise SourceError("Invalid source catalog anchor fields")
        validate_reference({**anchor, "version": 1, "book_id": 1, "sha256": catalog["sha256"]})
    return catalog


def blocks(document: dict):
    for block in document.get("children", []):
        yield block
        yield from blocks(block)


def attach_sources(document: dict, mapping: Any, catalog: dict, book_id: int) -> dict:
    if not isinstance(mapping, dict) or mapping.get("schema_version") != 1:
        raise SourceError("Heading mapping schema_version must be 1")
    entries = mapping.get("headings")
    headings = [b for b in blocks(document["document"])
                if b.get("type") == "heading" and b.get("data", {}).get("level") != 1]
    if not isinstance(entries, list) or len(entries) != len(headings):
        raise SourceError("Every detailed heading needs a source mapping or an unlinked reason")
    linked, unlinked = 0, []
    for ordinal, (heading, entry) in enumerate(zip(headings, entries), 1):
        data = heading["data"]
        text = "".join(p.get("insert", "") for p in data.get("delta", []))
        if (not isinstance(entry, dict) or entry.get("ordinal") != ordinal
                or entry.get("text") != text or entry.get("level") != data["level"]):
            raise SourceError(f"Heading {ordinal} order/text/level mismatch: {text!r}")
        source_id, reason = entry.get("source_id"), entry.get("unlinked_reason")
        if source_id is None:
            if not isinstance(reason, str) or not reason.strip():
                raise SourceError(f"Heading {ordinal} needs an explicit unlinked_reason")
            unlinked.append({"ordinal": ordinal, "text": text, "reason": reason.strip()})
            continue
        if reason is not None or not isinstance(source_id, str) or source_id not in catalog["anchors"]:
            raise SourceError(f"Heading {ordinal} has an unknown source ID or conflicting reason")
        data["book_source"] = {"version": 1, "book_id": book_id,
                               "sha256": catalog["sha256"],
                               **copy.deepcopy(catalog["anchors"][source_id])}
        linked += 1
    return {"linked": linked, "unlinked": unlinked}


class FlutterSourceValidator:
    """Use the app's resolver and AppFlowy serializer, not a Python approximation."""
    def __init__(self, mobile: Path, flutter: Path):
        self.mobile, self.flutter = mobile, flutter

    def validate(self, epub: Path, chapters: list[dict]) -> None:
        with tempfile.TemporaryDirectory(prefix="nx-book-sources-") as temp:
            request = Path(temp) / "request.json"
            report = Path(temp) / "report.json"
            request.write_text(json.dumps({"epub": str(epub.resolve()),
                "documents": [c["kgql_json_document"] for c in chapters]}), encoding="utf-8")
            env = {**os.environ, "NX_BOOK_SOURCE_REQUEST": str(request),
                   "NX_BOOK_SOURCE_REPORT": str(report)}
            try:
                result = subprocess.run([str(self.flutter), "test", "--no-pub",
                    "test/importer_source_validation_test.dart", "--reporter", "expanded"],
                    cwd=self.mobile / "nx_books", env=env, timeout=300, check=False)
            except (OSError, subprocess.TimeoutExpired) as error:
                raise SourceError(f"EPUB source validation failed: {error}") from error
            if result.returncode or not report.is_file():
                raise SourceError("EPUB source validation failed; inspect the resolver error above")
            if json.loads(report.read_text()).get("documents") != len(chapters):
                raise SourceError("Incomplete EPUB source validation report")
