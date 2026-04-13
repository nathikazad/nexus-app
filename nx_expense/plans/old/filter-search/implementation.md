# Implementation plan: search, multi-select, and bulk apply

This complements [`select-search-feature-ui.md`](select-search-feature-ui.md) (reference HTML). Below is what will likely need to change in **`nx_expense/lib`** and whether **`nx_db`** must change.

---

## Summary

| Area | nx_expense | nx_db |
|------|------------|--------|
| Search (list) | Client-side filter on **already-loaded** list rows only; match **name + description** | **No** — no extra query |
| Multi-select | Selection state, alternate app bar, row chrome, hide FAB | No |
| Bulk tag / company / attribute | Orchestration: `SetModelRequest` + `updateModel` per expense (or batch if added later) | **Unlikely required** — reuse existing DTOs and `setKgqlModels` |
| Performance / UX for large batches | Progress, concurrency limits, error aggregation | Optional future: bulk mutation or server-side merge |

---

## `nx_expense/lib` — providers (`providers/expense_providers.dart`)

### 1. Search query

**Product rules (fixed):**

- Search runs **only on the transactions already listed** — i.e. the output of `expenseListForUiProvider` (month + filters + sort + client-side amount/relation filters already applied). **No** additional `get_kgql_models` call for search.
- Match **only** `Model.name` and `Model.description` (e.g. case-insensitive substring). Do **not** search tags, amounts, or relation names unless requirements change.

**Implementation:**

- Add a notifier (or `StateProvider<String?>`) for the **search query string** and whether the **search field is expanded** (if separate from the query).
- Add a **derived provider** (e.g. `expenseListDisplayedProvider`) that watches `expenseListForUiProvider` and applies the name/description filter when the query is non-empty.

**Summary row when search is active:** derive count and total from **`expenseListDisplayedProvider`** so the header stays aligned with the **same** rows search is narrowing (recommended; matches “only among listed transactions”).

### 2. Selection mode and selected IDs

- `expenseListSelectionModeProvider` — `bool` (or enum: `off` / `selecting`).
- `expenseListSelectedIdsProvider` — `Set<int>` (expense model ids).

**Interaction with search (product):**

- Entering selection mode **must not** clear search, filters, or sort. The list **remains the same** as immediately before — including a **search-narrowed** list.
- Build the list from **`expenseListDisplayedProvider`** (or equivalent) so selected row ids always refer to rows the user actually sees.

**Actions:**

- Toggle selection for one id.
- **Select all** / **Deselect all** apply only to **currently displayed** rows (after search). Do **not** expand selection to the full unfiltered month.

### 3. Invalidation after bulk writes

- After bulk updates, `invalidate` the same providers as `ExpenseFormScreen._submit`: at least `expenseListForUiProvider`, `expenseDetailProvider` for touched ids if cached, and any relation pickers if company/project changed (`relatedModelsProvider` is already invalidated per relation type in the form — mirror that).

---

## `nx_expense/lib` — UI (`screens/expense_list_screen.dart`)

### Toolbar row (summary + icons)

Current code already formats the summary as **`count · formattedTotal`** (no word “expenses”) when a total exists — aligned with the reference.

**Add:**

1. **Search** icon — toggles expanded search field **below** this row (same pattern as reference: icon order search → select → filter → sort).
2. **Select** icon — enters selection mode (or toggles).

**When search is expanded:**

- Insert a `TextField` / `SearchBar` row under the summary+icons, with clear/close affordance.

**When selection mode is on:**

- Replace or overlay the normal app bar with: **Close**, **“N selected”**, **Select all** / **Deselect all** (on the displayed list).
- Dim or ignore month strip / filter icons as in the reference (optional polish).

### List body

- **Normal mode:** keep `ExpenseCard` + `onTap` → detail route.
- **Selection mode:** each row should show a **leading checkbox** (or full-row toggle), **teal border** when selected, and **do not navigate** on card tap (toggle selection instead).

Implement via:

- `ExpenseCard` optional parameters: `selectionMode`, `selected`, `onSelectionTap`, **or**
- a thin wrapper widget around the card to avoid bloating `ExpenseCard`.

### Filter / sort sheets

- Add the same **search + select** icons to the **header area** of the embedded list behind sheets if you want parity with the reference mocks (optional; the app sheets are already full-screen overlays).

### FAB (add expense)

FAB is defined on **`StatefulShellRoute`** in `router.dart` (`showFab = currentIndex == 0`), not inside `ExpenseListScreen`.

**Change:** FAB visibility should be `currentIndex == 0 && !selectionMode`. Easiest pattern: wrap the shell `Scaffold` in a **`Consumer`** and `ref.watch(expenseListSelectionModeProvider)` (add `flutter_riverpod` import to `router.dart` if needed).

---

## `nx_expense/lib` — bulk apply flow

### Bottom sheet (“Apply tag, company, or attribute”)

- New widget (e.g. `widgets/expense_bulk_apply_sheet.dart`) with three entries matching the reference:
  - **Tag** — navigate to or embed flows that reuse **`TagPicker`** / tag tree from `expense_form_screen` / `widgets/tag_picker.dart` / `tag_tree_tile.dart`, in a **bulk** mode (only return chosen tag system + node(s)).
  - **Company / project** — reuse **`RelationPicker`** patterns from `widgets/relation_picker.dart` and form screen.
  - **Attribute** — same as picking a tag system + value for non-category systems, or route to **`TagBrowserScreen`**-like flow with a **bulk** completion callback.

### Applying changes (writes)

There is **no** dedicated bulk API in the app today. **`nx_db`** already exposes:

- `createModel` / `updateModel` → `setKgqlModels` with `SetModelRequest` (`tags`, `relations`, `attributes`, …).

**Implementation strategy:**

1. For each selected expense **id**, build a `SetModelRequest` with `id` set and only the fields you intend to change.
2. Call `updateModel(container, request)` in sequence or with a small concurrency cap (e.g. 3–5 at a time).

**Tag / attribute semantics (critical):**

- Single-expense edit builds a **full** tag map per system from local state (`expense_form_screen.dart`).
- For bulk “set Category to Food”, you must **not** drop other tag systems. Options:
  - **Fetch** each model with `fetchKgqlModelById` + `buildExpenseStruct`, merge new tag assignment into existing `Model` → `SetModelTag` list, then `updateModel`; or
  - Rely on backend **`set_kgql_models`** merge rules for partial `tags` payloads (verify against `servers/pgdb/docs/human-reference/set_kgql_models.md` — if a system is omitted, is it unchanged? If so, you can send **only** the changed `SetModelTag` entries).

Document the chosen behavior after reading the server doc; add unit tests if behavior is subtle.

**Relations (company / project):**

- Reuse the same `ModelRelation` + `link` / `create` shapes as the form. For bulk, usually **`link: [id]`** after user picks an existing company.
- Reuse **`shouldOmitRelationsOnExpenseUpdate`**-style logic only if you send full relation state; for targeted bulk relation updates, sending **only** the relation you change may be enough — again confirm server merge semantics.

### Error handling

- If 3 of 10 updates fail, show a **summary SnackBar** or dialog listing failures (id / message).
- Consider **transactional** expectations: partial success is likely unless the backend adds a true batch mutation.

---

## `nx_expense/lib` — other files likely touched

| File / area | Why |
|-------------|-----|
| `widgets/expense_card.dart` | Optional: selection visuals + tap behavior |
| `widgets/tag_picker.dart` / `tag_tree_tile.dart` | Optional `bulkMode` / completion callback |
| `widgets/relation_picker.dart` | Same for bulk company/project |
| `screens/tag_browser_screen.dart` | Optional entry with “apply to N expenses” |
| `screens/expense_form_screen.dart` | Reference for `SetModelRequest` assembly — may extract shared **tag/relation → request** helpers to a small `expense_bulk_write.dart` or `expense_model_payload.dart` to avoid duplication |
| `main.dart` | Unlikely unless you add routes for bulk sub-flows |

---

## `nx_db` — changes?

### Probably **no** changes for MVP

- **`SetModelRequest`**, **`SetModelTag`**, **`ModelRelation`**, **`updateModel`** — sufficient for per-row updates.
- **`fetchKgqlModels`** / `expenseListProvider` — list load is unchanged; **search** is purely **in-memory** filtering of that list on **name** and **description**.

### Optional later (only if product changes)

| Idea | Where |
|------|--------|
| Search fields beyond name/description, or server-side search | Backend filter / index + `kgql_fetch` helper |
| Single mutation **bulk set** (many ids, one tag payload) | New GraphQL field + `nx_db` wrapper — reduces round-trips and makes atomicity possible |
| Streaming / job API for thousands of rows | Backend + app progress UI |

---

## Testing suggestions

- **Widget tests:** search field visibility; selection toggles; FAB hidden in selection mode (may require pumping shell + branch).
- **Unit tests:** client-side search filter on `Model` stubs — **only** `name` / `description`; selection + search combined (select all count = displayed rows only); `SetModelRequest` merge helpers if extracted.
- **Integration:** optional manual test against staging: bulk tag 5 expenses, verify list + detail reflect tags.

---

## Order of work (suggested)

1. Providers: search query + displayed list + summary behavior decision.  
2. UI: search row + icons on list screen.  
3. Providers: selection mode + selected set + select/deselect all.  
4. UI: selection app bar, card checkboxes, hide FAB via `router.dart`.  
5. Bulk sheet + navigation into existing pickers with bulk callbacks.  
6. Bulk write helper + `updateModel` loop + invalidation + error aggregation.  
7. Polish: loading overlay, SnackBars, undo if feasible.
