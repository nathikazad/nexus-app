# Testing plan — search, multi-select, bulk apply (regression prevention)

This document lists **test types and cases** to lock in behavior described in [`select-search-feature-ui.md`](select-search-feature-ui.md) and [`implementation.md`](implementation.md). Implement tests as the feature lands; existing patterns live under `nx_expense/test/` (`expense_providers_test.dart`, `expense_card_widget_test.dart`, mocktail + `ProviderContainer` overrides).

---

## 1. Pure logic (unit tests, no Flutter)

**Best location:** `test/expense_list_search_filter_test.dart` (or next to any extracted helper, e.g. `lib/utils/expense_list_search.dart`).

**Subject:** A function that takes `List<Model> models`, `String query`, and returns the filtered list (or a predicate). Rules:

| Case | Expectation |
|------|-------------|
| Empty query | Returns all models (same order as input). |
| Whitespace-only query | Treat as empty — return all. |
| Case-insensitive match on **name** | `"Coffee"` matches query `coffee`, `COFFEE`. |
| Match on **description** | Model with empty name but description containing query is included. |
| **No** match on tags | Tag contains query string but name/description do not → excluded. |
| **No** match on amount / attributes | Even if `attributes['cost']` stringifies to query → excluded. |
| **No** match on relation names | `relations['Company']` names contain query but name/description do not → excluded. |
| Null / missing description | `description == null` or `''` — only name participates; no crash. |
| Unicode / accents | Optional: document whether you normalize; at minimum no crash on non-ASCII. |

These tests **do not** need GraphQL — build `Model` instances inline (see `expense_card_widget_test.dart`).

---

## 2. Provider / state (Riverpod)

**Best location:** extend `test/expense_providers_test.dart` or add `test/expense_list_display_selection_test.dart`.

Use **`ProviderContainer`** + **`overrides`** to supply fake `expenseListForUiProvider` data (list of `Model`) and avoid real GraphQL for the new derived logic.

### Search + displayed list

| Case | Expectation |
|------|-------------|
| No search query | `expenseListDisplayedProvider` equals mocked `expenseListForUiProvider` list. |
| Query set | Displayed list is filtered subset; count matches manual filter on name/description. |
| Summary provider (if wired) | When search active, summary count/total matches **displayed** rows only (same sum rule as today for amount key). |

### Selection mode

| Case | Expectation |
|------|-------------|
| Default | Selection mode off; selected set empty. |
| Enter selection | Flag on; selected unchanged until user acts. |
| **Enter selection with search active** | Search query **unchanged**; displayed list unchanged **ids**; same order as before entering selection. |
| Toggle one id | Set contains id; second toggle removes. |
| **Select all** | Selected ids == ids of **current displayed** list exactly (order-independent set equality). |
| **Deselect all** | Selected set empty; displayed list unchanged. |
| **Select all** with search narrowing to 3 rows | Selected size == 3, not full unfiltered list size. |
| Exit selection mode | Clear selection and/or flag (define product rule; test the chosen rule consistently). |

### Invalidation (smoke)

After bulk update completes (mock `updateModel`):

- `expenseListForUiProvider` is invalidated or refreshed (existing pattern from form submit).

---

## 3. Widget tests — `ExpenseListScreen`

**Best location:** `test/expense_list_screen_test.dart` (new).

Use **`ProviderScope`** with **`overrides`**:

- `expenseSchemaProvider` → `AsyncValue.data` minimal `ModelType` (Expense).
- `expenseListForUiProvider` → `AsyncValue.data` with a **fixed list** of 2–3 `Model`s.
- `expenseListSummaryProvider` → `AsyncValue.data` matching expectations.
- New providers: search query, selection mode, displayed list — override as needed.

| Case | Expectation |
|------|-------------|
| Toolbar icons | Finds search, select, filter, sort (or semantic labels / icons you assign). |
| Tap search | Search field appears **below** summary row (find `TextField` / `SearchBar`). |
| Type query | List updates to visible rows (if you pump provider updates). |
| Tap select | Selection UI visible (checkboxes or selection affordance); **search text preserved** if you pump with same overrides. |
| **Tap row in selection mode** | Does **not** push detail route (no `/expense/` route change); selection toggles. |
| **Tap row in normal mode** | Navigates to detail (existing behavior) — guard against regressions. |
| Bulk bar | When selection non-empty and mode on, **Apply** entry visible; optional tap opens sheet mock. |

**Note:** `GoRouter` in tests can use a minimal `MaterialApp.router` or `Navigator` + `onGenerateRoute` if full shell is heavy; goal is **behavior**, not pixel-perfect router.

---

## 4. Widget tests — shell / FAB (`router.dart`)

**Best location:** `test/expense_shell_fab_test.dart` (new).

| Case | Expectation |
|------|-------------|
| Expenses tab, not selecting | FAB present (`FloatingActionButton`). |
| Expenses tab, **selection mode on** | FAB **absent** (or `null`). |
| Other tabs | FAB absent (existing behavior) — ensure selection on expenses doesn’t leak. |

May require **`Consumer`** + `ProviderScope` with a stub `expenseListSelectionModeProvider`.

---

## 5. Widget tests — `ExpenseCard` (or wrapper)

**Best location:** extend `test/expense_card_widget_test.dart` or add `test/expense_card_selection_test.dart`.

| Case | Expectation |
|------|-------------|
| `selectionMode: false` | Looks like today; tap calls `onTap`. |
| `selectionMode: true`, `selected: false` | Checkbox (or border) in **unchecked** state. |
| `selectionMode: true`, `selected: true` | **Checked** / teal border per design. |
| Tap in selection mode | Invokes `onSelectionTap` (or equivalent), not `onTap` → detail. |

---

## 6. Bulk apply orchestration (unit / integration)

**Best location:** `test/expense_bulk_write_test.dart` (new).

Mock **`updateModel`** (or the `GraphQLClient` mutation) so no network runs.

| Case | Expectation |
|------|-------------|
| 0 selected | No mutation calls; or early return with SnackBar (product rule). |
| N selected | Exactly **N** `updateModel` calls (or batched if you implement batching). |
| **Tag merge** | If you extract a helper: given existing `Model` + new tag choice, `SetModelRequest` tags preserve other systems. |
| Partial failure | Second call throws; first two succeed — verify error aggregation and **no** silent swallow (assert SnackBar / result type). |

---

## 7. `expense_schema` / helpers (if extracted)

If you add **`filterModelsBySearchQuery`** or **`mergeBulkTagRequest`** in `lib/`:

- **Round-trip** tests with fixtures from `expense_schema_test.dart` style.
- Golden tests are **optional**; not required for regression on logic.

---

## 8. Integration / E2E (optional)

**Best location:** `integration_test/` or extend `test/expense_integration_test.dart` if you already have a harness.

- Login flow, open list, search, select two, open bulk apply — **only** if CI can run against a test backend or recorded GraphQL.

Mark as **optional**; unit + widget coverage above catch most regressions.

---

## 9. Regression matrix (quick reference)

| Risk | Primary test layer |
|------|---------------------|
| Search hits tags/amounts by mistake | §1 unit tests |
| Search triggers extra API calls | §2 provider (mock client call count on `expenseListProvider` if needed) |
| Select all expands beyond visible rows | §2 selection tests |
| Select clears search | §2 + §3 |
| FAB overlaps selection | §4 |
| Detail opens during selection | §3 + §5 |
| Bulk drops tags on other systems | §6 merge tests |

---

## 10. CI

- Run `flutter test` in `nx_expense` on every PR touching `lib/providers`, `lib/screens/expense_list_screen.dart`, `router.dart`, or new bulk helpers.

Link this doc from `implementation.md` when convenient (optional).
