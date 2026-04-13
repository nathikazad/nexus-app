# Select, search, and bulk-apply — reference UI

This document describes the **HTML reference mockups** under `nx_expense/reference/` that define the expense list behaviors for **multi-select**, **search**, and **bulk labeling** (tag, company, attribute). These are design references for the Flutter app, not implemented product UI.

## Summary row (count + total)

On the main expense list toolbar row (the line with the count on the left and action icons on the right):

- **Before:** `12 expenses · $1,240.00`
- **After:** `12 · $1,240.00`

The word **“expenses”** was removed to save horizontal space. The number is still the transaction count for the current scope (e.g. month + filters).

**Files:** `reference/expense-list-main.html`, and the same short form on `reference/expense-list-filter-bottom-sheet-open.html` and `reference/expense-list-sort-bottom-sheet-open.html` (`5 · $420.00` / `12 · $1,240.00`).

---

## Toolbar icon order (main list)

Left to right, **after** the summary text:

1. **Search** — opens search mode (see below).
2. **Select** — opens selection mode (see below).
3. **Filter** — existing filter bottom sheet reference.
4. **Sort** — existing sort bottom sheet reference.

**File:** `reference/expense-list-main.html`.

---

## Search

### Scope (product)

- Search **only narrows the rows already on the list** — the same transactions the user already loaded for the current month, filters, and sort. It does **not** run a separate server query or search the full database.
- In the app, matching is limited to **name** and **description** (case-insensitive substring is typical). It does **not** search tags, amounts, or company names unless product changes later.

### Behavior

- Tapping **search** does **not** navigate away from the list conceptually; the reference uses a **separate HTML file** to show the “search open” state.
- When search is active, a **search field appears directly below** the summary + icon row (still above the scrollable transaction list).
- The **search icon** is shown in the **teal active** state while the field is visible (tap it or use close affordances to collapse — see reference links).

### Reference screen

- **`reference/expense-list-search-open.html`** — full-width field with leading magnifier, placeholder (“Search transactions…”), and a **close** control on the right (X) that returns to the main list.

### Icon name (Iconify + Solar)

The Solar set’s search icon slug is **`solar:magnifer-linear`** (note the spelling **magnifer**, not `magnifier`). Using the wrong name results in an **empty icon** in the browser.

---

## Selection mode

### Interaction with search

- Tapping **Select** **does not reset** search or the filter/sort state. The list **stays exactly as shown** — if search is active, selection mode applies to **those same filtered rows only**.
- **Select all** / **Deselect all** operate on the **currently listed** transactions (after search), not the full month behind the scenes.

### Entry

- From the main list, **Select** (checklist-style icon) opens selection mode.

### Reference screen(s)

- **`reference/expense-list-select.html`** contains **two static states** on one page:
  - **Partial selection** — e.g. “2 selected”, **Select all** in the app bar (anchor to the second mock).
  - **All selected** (for visible list items in the mock) — e.g. “3 selected”, **Deselect all** in the app bar (anchor back).

There is **no long-press** entry in this reference; **only** the toolbar **Select** control.

### Layout and chrome

- **App bar:** Close/dismiss, centered **“N selected”**, **Select all** or **Deselect all** on the trailing edge.
- **Month/year row** and the **filter/sort** icons are shown **muted** (non-interactive in the mock) so focus stays on selection.
- **Summary** under that uses a compact form, e.g. `2 of 12 · $28.50` in the static mock. In the app, the denominator should match **how many rows are currently listed** (e.g. if search shows 3 rows, **Select all** selects those 3 and copy can read `2 of 3 · …`).
- **Rows:** Leading **checkbox**, selected rows use a **teal border**; tapping toggles selection (buttons in the mock).
- **FAB** is **omitted** in selection mode so it does not compete with bulk actions.
- **Bottom bar (above tab bar):** Primary action **“Apply tag, company, or attribute”** → links to the bulk-apply sheet reference.

### Toolbar parity

The muted icon strip includes **search**, **select** (teal), **filter**, and **sort** so it stays visually aligned with the main list toolbar.

---

## Bulk apply (tag / company / attribute)

After choosing transactions, the user picks **what** to set:

- **`reference/expense-list-bulk-apply-sheet.html`** — dimmed list + **bottom sheet** with three rows:
  - **Tag** → `reference/select-tag.html`
  - **Company or project** → `reference/select-relation.html`
  - **Attribute** (pick a tag system, then value) → `reference/tag-browser-screen.html`

Tapping the backdrop closes back to the selection reference (`expense-list-select.html`).

---

## Index of reference screens

**`reference/index.html`** lists all reference pages, including:

- Expense list — search field open  
- Expense list — select (multi-select, select / deselect all)  
- Expense list — bulk apply sheet  

---

## Implementation notes for Flutter

- **Search:** Toggle expands/collapses a field **below** the summary + icon row; preserve the same icon order when implementing. Filter **only** `Model.name` and `Model.description` on the list you already have from `expenseListForUiProvider` (no extra fetch).
- **Selection:** Maintain a **selection mode** flag; swap app bar and list item behavior; hide FAB; show **bulk action** bar when `N > 0` (or always in selection mode with disabled state — product choice). **Do not** clear search when entering selection — the visible list is the source of truth for rows and for **Select all**.
- **Bulk apply:** Single entry point that routes to tag picker, relation picker, or tag-system browser, with **bulk** copy in titles where applicable.
