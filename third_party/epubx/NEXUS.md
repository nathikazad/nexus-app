# Nexus parser fork

Source: https://pub.dev/api/archives/epubx-4.0.0.tar.gz
Verified SHA256: 0ab9354efa177c4be52c46f857bc15bf83f83a92667fb673465c8f89fca26db3
Original MIT license retained.

Changes:
- Migrate image 3 to image 4 and archive 3 to archive 4, compatible with
  AppFlowy's existing PDF dependency. Adapt cover decoding to typed bytes.
- Preserve archive's Uint8List buffers rather than expanding image/font data
  into growable integer lists.
- Optional `decodeCover: false`: renderer already decodes visible images.
- Reject archives exceeding 20,000 entries or 128 MiB declared expanded size.
  This is a resource guard, not a guarantee against every malformed archive.

Upstream example apps and legacy pre-null-safety tests are omitted. Current
compatibility, rendering and PDF regression tests live in
`nx_books/test/epub_reader_test.dart`.

AppFlowy itself is not modified. Do not downgrade its PDF dependency to make
this reader resolve. Keep reader-specific changes within the two EPUB forks.
