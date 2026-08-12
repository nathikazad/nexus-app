# Nexus book-summary importer

This package compiles structured chapter summaries into a deterministic
`kgql-import.json`, then imports that manifest through the existing KGQL
GraphQL API. It does not require or make KGQL schema, server, or database-layer
changes.

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

Execution always requires a validated production backup. The importer writes a
local `kgql-import.receipt.json` containing the backup path, checksum, created
Book Chapter IDs, and verification result.

## Safety properties

- `--dry-run` performs no writes and no backup.
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
