# Nexus book-summary importer

This package compiles structured chapter summaries into a deterministic
`kgql-import.json`, then imports that manifest through the existing KGQL
GraphQL API. Imports travel through the `hetzner-personal` SSH host and execute
against GraphQL inside the Nexus Docker network. The server-side relay reads the
internal secret in the container, so no production credential is copied to the
Mac. It does not require or make KGQL schema, server, or database-layer changes.

## Book package format

```text
my-book/
├── book.json
└── chapters/
    ├── ch01.md
    └── ch02.md
```

`book.json`:

```json
{
  "schema_version": 1,
  "book": {
    "kgql_id": 4539,
    "expected_name": "Nonviolent Communication",
    "author": "Marshall Rosenberg"
  },
  "chapters": [
    {
      "number": 1,
      "title": "Giving From the Heart",
      "file": "chapters/ch01.md",
      "source_words": 3936
    }
  ]
}
```

Each chapter file contains exactly two marker-delimited sections. The title is
metadata and must not be repeated as an H1.

When `source_words` is present, compilation requires a detailed-summary ratio
between 18.5% and 20.5%. An intentional exception must include a non-empty
`compression_note` on that chapter entry.

```markdown
<!-- SHORT_SUMMARY -->

One prose paragraph containing the short summary.

<!-- DETAILED_SUMMARY -->

## First section

Detailed summary text...
```

## Commands

From `mobile/nx_books`:

```bash
python3 importer/book_summaries.py compile /absolute/path/to/my-book

python3 importer/book_summaries.py import \
  /absolute/path/to/my-book/build/kgql-import.json \
  --dry-run

python3 importer/book_summaries.py import \
  /absolute/path/to/my-book/build/kgql-import.json \
  --execute
```

If an import stops after creating some Book Chapters:

```bash
python3 importer/book_summaries.py import \
  /absolute/path/to/my-book/build/kgql-import.json \
  --execute \
  --resume
```

Both commands default to Nexus user ID `1`, domain ID `1`, and SSH target
`hetzner-personal`. The importer writes a local `kgql-import.receipt.json`
containing created Book Chapter IDs and the verification result. Production
backups are handled independently by the Hetzner backup schedule, not by an
individual book import.

## Safety properties

- `--dry-run` performs no writes.
- Imports target Hetzner over SSH; they never target the Pi implicitly.
- Chapter titles and numbers come from `book.json`, not filename parsing.
- Each detailed summary is stored as a `Book Chapter` with its
  `chapter_number` attribute.
- Books link chapters through `book_book_chapter`; editor links remain
  `kgql://Document/<id>` because Book Chapter inherits Document.
- Detailed KGQL bodies exclude only the generated matching H1.
- KGQL attributes are always sent through the existing `attributes` array.
- Relations are always sent through the existing `relations` array.
- Book updates never send `model_type`, preventing accidental type changes.
- Existing Book blocks, tags, reading metadata, pinned state, and `view_state`
  are preserved.
- Exact AppFlowy bodies, plain text, descriptions, hashes, inline links,
  `Status: Draft`, and graph relations are independently read back.

## Tests

```bash
python3 -m unittest discover -s importer/tests -v
```
# EPUB heading source metadata

Linked EPUB packages add `"epub_sources": "sources/epub-anchors.json"` at the
top level of `book.json`, and `"heading_sources": "chapters/ch01.sources.json"`
to each chapter. Compile with `--epub /absolute/path/to/original.epub`. The source
file is read, not copied; ordinary summary packages remain supported.

Catalog shape (produced by the book-summary skill's extractor):

```json
{"schema_version":1,"format":"epub","sha256":"<file SHA-256>","anchors":{
  "src-example":{"resource":"OPS/ch1.xhtml","fragment":"intro","quote":{"exact":"Source heading"}}
}}
```

Heading sidecar shape:

```json
{"schema_version":1,"headings":[
  {"ordinal":1,"level":2,"text":"Summary heading","source_id":"src-example"},
  {"ordinal":2,"level":2,"text":"Synthesis","unlinked_reason":"No single source passage"}
]}
```

Cover every detailed heading in document order, excluding the generated H1.
Text means rendered plain text, not Markdown syntax. The compiler rejects stale
heading mappings, unknown IDs, incorrect file hashes and unsafe paths, then
attaches `data.book_source` before hashing. It invokes a local Flutter batch
test to verify AppFlowy round-trips and resolve each source with the actual
reader. The compiled `source_coverage` reports linked and explicitly unlinked
headings. Import checks the uploaded `book_file.sha256` and reference ownership;
it never adds EPUB metadata to Book overview headings or short summaries.

Run unit tests with `python3 -m unittest discover -s importer/tests -t .`.
Set `NX_SOURCE_INTEGRATION=1` to include real Flutter conversion/resolution tests.
Those tests use a temporary synthetic EPUB and make no production requests.
