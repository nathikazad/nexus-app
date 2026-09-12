# Chapter heading source references

Each heading may store `data.book_source` alongside its existing `level` and
`delta`. This is node metadata, not a hyperlink on the heading text:

```json
{
  "version": 1,
  "book_id": 4427,
  "sha256": "<64-character attachment SHA-256>",
  "resource": "OEBPS/chap01.html",
  "quote": {"exact": "Netflix Cracks the Code"}
}
```

`resource` is relative to the EPUB archive root. `fragment` is an optional
element ID. A quote can include `prefix` and `suffix` to disambiguate text in
the same paragraph. Version 1 resolves to the beginning of the uniquely
identified paragraph; it does not store a page number or renderer index.
Missing and ambiguous targets fail visibly rather than choosing another page.

Responsibilities:

- KGQL stores the existing chapter JSON; no new catalog attribute is needed.
- AppFlowy preserves arbitrary heading data, including through text edits.
- The shared document reader provides a generic heading action callback. It
  does not understand Book IDs, EPUB files or server endpoints.
- The Books host exposes the action only for actual `Book Chapter` models with
  the matching `book_book_chapter` relation. Actual type/relations travel with
  document snapshots, including offline snapshots.
- `BookSource` validates the persisted representation. `epub_source_resolver`
  adapts it to the current renderer using only the cached file. A different
  renderer can replace that adapter without migrating persisted references.
- The host verifies the attachment hash before resolving. Reference visits do
  not save reading progress. Normal book opens continue to save progress.

The production data pilot is restricted to the three existing headings of
chapter 5754 / book 4427 in domain 1. There are no pilot IDs in the active
parsing/navigation code. The superseded hardcoded URL experiment has been
removed; these structured references remain the supported implementation.

The guarded content script is
`servers/pgdb/scripts/structured_seven_powers_sources.sql`. It verifies existing
model identities, parent relation, file hash and old destinations; replaces only
the three known references; and is idempotent. `apply=false` rolls back its
preview, and `apply=true` persists the update.

Summary regeneration/importers must preserve or regenerate `book_source` when
replacing heading nodes. Normal node serialization preserves it, but a complete
document replacement cannot automatically infer equivalent new headings.

`importer/book_summaries.py compile` supports an `epub_sources` catalog in the
package manifest and a `heading_sources` JSON sidecar on each chapter. Supply
the original file with `--epub`; it is not copied. The compiler matches every
heading by ordinal, rendered text, and level, attaches references before
hashing, and validates using `test/importer_source_validation_test.dart` (the
same resolver used by the app). Unlinked headings require explicit reasons.
Import compares the source hash against the live Book's `book_file.sha256`.
See `importer/README.md` for the package contract.
