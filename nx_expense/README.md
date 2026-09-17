# nx_expense

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

flutter build web --release --base-href /expenses/
ssh nathik@100.108.43.37 'mkdir -p ~/Nexus/nexus-server/mcp/server/static/nx_expense'
rsync -az --delete build/web/ nathik@100.108.43.37:~/Nexus/nexus-server/mcp/server/static/nx_expense/
### Expense sync and receipt files

`AppDataHost` connects Expense to the shared session used by Books and Docs.
It checks the server revision on launch, resume, reconnect and server change
notifications, with a 30-second recovery check. Changed revisions invalidate
visible providers. Native devices also reconcile the complete Expense manifest
into a server/user/domain-scoped `ExpenseStore`; web sessions never create it.
Foreground pages use live reads, with the native snapshot available offline.
Expense and Order screen mappers preserve relation attributes in that fallback.

Receipt uploads use `/apps/expense/receipts`, which publishes an immutable file
and records its SHA-256 in the timeline payload. That payload participates in the
server record/collection/root hashes. The sync worker does not hash file bytes
again on every poll: replacements must publish a new file and update the event
or link, rather than silently overwrite an existing file on disk.

Native receipt downloads use the shared `AttachmentQueue` and
`BinaryContentFiles`, just like Books' PDF/EPUB downloads. Both linked and
unlinked receipt images and PDFs are downloaded in the background. The file
index is scoped to the same account and domain, keyed by filename and expected
hash. Reads verify cached bytes, repair missing/corrupt files online and reject
mismatched server bytes. Web viewers download into memory only. Older receipts
without a server hash still get local integrity verification; replacing those
should change the filename. A receipt becomes available offline after its
background download (or its first successful open) completes.

Receipt attachment controls still require a connection to upload and link a
receipt. This integration does not change the existing expense editing workflow
into an offline editor. Product image URLs continue to use their existing image
loader; the persistent file cache here covers receipt attachments.
