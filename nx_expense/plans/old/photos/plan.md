# Expense bill photos (camera / library → MCP → KGQL link)

## Goal

- On expense detail, **+** opens a chooser: **Camera** or **Photo library**.
- After capture/selection, **upload** the image to the MCP HTTP server so it is stored under `IMAGE_DIR/<user_id>/` and a **`timeline_events` row** is created (`eventType: image`, `source: expense_app`), matching `record_image_timeline_event` behavior in `servers/mcp/http_server.py`.
- **Link** that timeline event to the current **Expense** so it appears in the app and can be listed/removed consistently with Teller links.
- **Display** images via `GET /images/file?name=<basename>` (same auth / `X-User-Id` conventions as other MCP image routes).

## Product decisions (confirmed)

1. **Multiple bills per expense:** Yes — show a row of bill thumbnails plus **+** (same pattern as the reference HTML).
2. **Unlink:** Yes — reuse **`deleteExpenseTimelineLink`** by link id, same as Teller.
3. **Offline / retry:** Out of scope for this plan.

## Architecture decision

- **Link expense ↔ timeline event on the app** immediately after a successful upload, using existing GraphQL in `lib/data/expense_timeline_api.dart`:
  - `linkExpenseToTimelineEvent(graphqlClient, modelId: expenseId, eventTime: parsedTime, eventId: timelineEventIdString)`.
- **Require the upload HTTP response** to include **`timelineEvent.id`** and **`timelineEvent.time`** (ISO 8601) from the created row so the app can link without an extra query.

**Rationale:** Same pattern as `createTellerTimelineEventAndLinkToExpense`. Server-only linking (single POST with `expense_id`) would duplicate KGQL link logic in Python.

## Server (`servers/mcp/http_server.py`) — required changes

1. **`POST /snapshots`** (or a dedicated route that shares the same save + `record_image_timeline_event` path)
   - Accept **`source=expense_app`** (today only `necklace|desktop` is allowed).
   - Define **filename / `timestamp`** rules for mobile (camera vs library): align with existing helpers (`_digits_from_timestamp_form`, `_event_time_iso_from_local_12digit`) and `record_image_timeline_event`.

2. **Response body**
   - After a successful save + timeline insert, return JSON such as:
     `{ "ok": true, "filename": "...", "timelineEvent": { "id": "...", "time": "..." } }`
   - Refactor `record_image_timeline_event` to **return** `id` + `time` (it already parses them for logging).

3. **Optional:** `meta` JSON on upload for debug only — **not** the source of truth for linking; use `model_timeline_event_links`.

4. **`/images/dates` and `/images/day`** currently restrict `source` to `necklace|desktop`. Expense bills may stay **out** of those listings unless extended; the app loads bills via **expense-linked** image timeline rows.

## App — Flutter (`mobile/nx_expense`)

### Dependencies & platform

- `image_picker` (or equivalent) for camera vs gallery.
- iOS: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` (and any strings required for the chosen APIs).
- Android: camera/storage permissions per API level.

### Config

- MCP base URL + **`X-User-Id`** header consistent with the rest of the app.

### Flow

1. User taps **+** → bottom sheet / action sheet: **Take photo** | **Choose from library** (and cancel).
2. Pick image → `multipart/form-data` `POST` to `/snapshots` with `file`, `source=expense_app`, `timestamp` / `timezone` per server contract.
3. Parse response → **`timelineEvent.id`** + **`timelineEvent.time`** → parse `eventTime` for `linkExpenseToTimelineEvent`.
4. Call **`linkExpenseToTimelineEvent`** with the current `expenseId`.
5. `ref.invalidate(expenseTimelineLinksProvider(expenseId))` and any detail providers as needed.

### Data model / UI split (critical)

- `expenseTimelineLinksQuery` returns mixed link types. **Expense detail** and **ExpenseTellerLinksFormSection** currently assume **Teller-shaped** payloads (`amount`, headline helpers, etc.).
- Parse **`eventType`** from `timelineEventByEventTimeAndEventId` (already in the query) and:
  - **Teller section:** only rows with `eventType == teller_transaction` (keep current UI).
  - **Bills section (below Teller):** rows with `eventType == image` — thumbnail from `payload.path` basename → authenticated image URL `${base}/images/file?name=$basename`, plus **+** for another bill.
- **Unlink** for a bill: **`deleteExpenseTimelineLink`** with that row’s link id (same as Teller).

### Testing

- Unit: upload response parsing → link mutation arguments.
- Widget tests: chooser + mocked upload/GraphQL where practical.

## Open items

- Exact **timestamp** contract for library picks (EXIF vs “now”) — align with server validation.
- Optional: include **`fileUrl`** in upload response for convenience (basename + base URL).

## References (code)

- Upload + `record_image_timeline_event`: `servers/mcp/http_server.py` (`upload_snapshot`, `record_image_timeline_event`).
- File bytes: `GET /images/file` in the same file.
- Link mutations/queries: `mobile/nx_expense/lib/data/expense_timeline_api.dart` (`linkExpenseToTimelineEvent`, `expenseTimelineLinksQuery`, `deleteExpenseTimelineLink`).
