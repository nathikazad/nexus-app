# macOS storage measurement — 2026-09-06

Installed the signed release build at `/Applications/Nx Docs.app` and verified
its bundle signature and network/audio entitlements. The previous app bundle
and pre-migration normal SQLite database were backed up under
`/tmp/nx-docs-install-backup.uiqW2Q`.

## Fresh-download run

The release executable ran with `NX_DOCS_STORAGE_PROFILE=1`. This selects a
separate database/content namespace; it does not clear the normal account's
documents or pending edits. The same binary subsequently reopened without
this environment variable for normal use.

Metric: whole-process resident set size (RSS), in MiB (1,048,576 bytes), not
virtual address space and not the Dart heap alone. The boundary samples use
`ProcessInfo.currentRss`; the settled sample uses macOS `ps` RSS in KiB.

| Point | Resident memory |
| --- | ---: |
| Before document download; empty local document index | 122.9 MiB |
| Immediately after all 758 documents downloaded | 203.8 MiB |
| After the library/document view settled | 190.4 MiB |
| Peak RSS recorded through first download completion | 205.4 MiB |

The immediate increase was 80.9 MiB. This includes UI, catalog projections,
network decoding and transient allocation, not just retained document bodies.
The UI displayed a loaded document and the Recent list. The test database held
758 body references, 13,197,562 logical content bytes, and zero queued writes.

Boundary timestamps (UTC): before `10:34:17.155092`, after
`10:35:41.186994`; process ID 19219. Total cold sync took about 84 seconds.
The first page completed around 59 seconds after the initial boundary, indicating
that initial header discovery/startup network work remains a latency concern.
No claim is made that file storage alone fixes all loading delay.

The old running app was a long-lived debug build, so its memory was not used as
a before/after optimization comparison. These results compare two stages of
one release-process run. They are not Android memory/frame-time measurements.

The optional diagnostic mode logs only stage, timestamp, PID, memory counters
and document counts. Normal launches do not enable it. Reusing its existing
namespace is a warm-cache run, not a new empty-cache measurement.
