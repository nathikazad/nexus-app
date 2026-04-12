# Expense App — Full Plan

A standalone Flutter app (`nx_expense`) for tracking expenses. It uses the existing `nx_db` package for auth, GraphQL, and data access, and talks to the same PostGraphile/PGDB backend. No backend changes required.

**Design principle:** The only hardcoded value is the model type name `"Expense"`. Everything else — attributes, relations, tag systems, tag nodes — is discovered at runtime from `get_kgql_model_type` and rendered dynamically.

---

## 1. Project Setup

### 1.1 Create the Flutter project

```bash
cd mobile
flutter create nx_expense
```

### 1.2 `nx_expense/pubspec.yaml` dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.2.0
  go_router: ^17.0.1
  intl: ^0.20.2
  fl_chart: ^1.2.0
  nx_db:
    path: ../nx_db
```

No need to add `graphql_flutter`, `shared_preferences`, etc. directly — `nx_db` pulls them transitively.

### 1.3 Folder structure

```
nx_expense/lib/
├── main.dart
├── router.dart
├── theme.dart
├── providers/
│   ├── expense_providers.dart      # expense-specific Riverpod providers
│   └── aggregate_providers.dart    # aggregation providers (sum, group-by)
├── screens/
│   ├── expense_list_screen.dart    # home — list of all expenses
│   ├── expense_detail_screen.dart  # single expense view
│   ├── expense_form_screen.dart    # create / edit expense
│   ├── dashboard_screen.dart       # aggregation charts
│   ├── tag_systems_screen.dart     # list tag systems for Expense
│   ├── tag_system_form_screen.dart # create / edit a tag system + its nodes
│   └── tag_browser_screen.dart     # hierarchical tree view for any tag system
├── widgets/
│   ├── expense_card.dart           # list tile for an expense
│   ├── tag_chip.dart               # colored chip for a tag
│   ├── tag_picker.dart             # bottom sheet to pick tag nodes (generic)
│   ├── relation_picker.dart        # bottom sheet to pick/create related models
│   ├── stat_card.dart              # dashboard summary card
│   ├── tag_tree_tile.dart          # recursive tree tile for hierarchical tags
│   └── tag_node_editor.dart        # inline editor for nodes in tag system form
```

---

## 2. Core Concept: Schema-Driven UI

### 2.1 The metadata provider

On app launch (after login), the app fetches the Expense model type metadata:

```
get_kgql_model_type({
  model_types: ["Expense"],
  struct: {
    id: true, name: true, type_kind: true,
    attributes: true,
    relations: true,
    tag_systems: true
  }
})
```

This returns a `ModelType` with:

- **`attributes`** — list of `AttributeDefinition` objects, each with `key`, `value_type` (string, number, datetime, boolean, json), and `required`
- **`relations`** — list of `RelationshipType` objects, each with `target_model_type` name and relation metadata
- **`tagSystems`** — list of `TagSystem` objects, each with `name`, `is_hierarchical`, `selection_mode` (exclusive/multiple), and nested `nodes` tree

This metadata is cached in a Riverpod provider (`expenseSchemaProvider`) and drives all UI rendering.

### 2.2 How each piece of the UI uses the schema

| UI concern | Driven by |
|---|---|
| **List struct** — what fields to request | `attributes` → each key becomes a struct field; `relations` → each target becomes a struct relation; `tagSystems` → `"tags": true` |
| **Expense card** — what to display | First number attribute shown as "amount", name shown as title, all tag values shown as chips |
| **Detail screen** — sections | One section per attribute, one section per relation type, one section per tag system |
| **Form fields** — inputs | One input per attribute (type → widget mapping), one picker per relation, one tag picker per tag system |
| **Tag picker mode** | `selection_mode == "exclusive"` → single-select; `"multiple"` → multi-select |
| **Tag picker layout** | `is_hierarchical == true` → tree view; `false` → flat chip list |
| **Filter chips** | Generated from all tag systems: each system's root/leaf nodes become filter options |
| **Dashboard charts** | One "group by tag:X" chart per tag system; one "group by relation" chart per relation type; one "group by day" chart always |
| **Aggregate metric key** | First `number` attribute found (e.g. `cost`) — or user-selectable if multiple number attributes exist |

### 2.3 Attribute type → widget mapping

| `value_type` | List display | Form widget | Aggregate support |
|---|---|---|---|
| `number` | Formatted number (currency if first) | Number text field | sum, avg, min, max |
| `string` | Text | Text field | — |
| `datetime` | Formatted date/time | Date/time picker | group-by with window |
| `boolean` | Check icon | Switch | — |
| `json` | "View JSON" link | JSON text area (or hidden) | — |

---

## 3. nx_db Updates (prerequisite)

The `nx_db` package currently has zero tag awareness. These changes are required before the expense app can be built.

### 3.1 New Dart models

#### `nx_db/lib/src/models/TagSystem.dart`

```dart
class TagSystem {
  final int id;
  final String name;
  final bool isHierarchical;
  final String selectionMode; // "exclusive" | "multiple"
  final int? modelTypeId;
  final List<TagNode> nodes;

  factory TagSystem.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

#### `nx_db/lib/src/models/TagNode.dart`

```dart
class TagNode {
  final int id;
  final String name;
  final int? sortOrder;
  final List<TagNode>? children;

  factory TagNode.fromJson(Map<String, dynamic> json); // recursive
  Map<String, dynamic> toJson();

  /// Flatten the tree to a list of leaf names (for flat display)
  List<String> get leafNames;
}
```

### 3.2 Update existing models

#### `ModelType` — add `tagSystems` field

The backend's `get_kgql_model_type` already returns a `tag_systems` array. `ModelType` needs:

```dart
final List<TagSystem>? tagSystems;
```

Parsed in `fromJson` from the `tag_systems` key.

#### `Model` — add `tags` field

The backend's `get_kgql_models` returns tags as a map when `tags: true` is in the struct (e.g. `{"Category": ["Coffee"], "Judgment": ["Unnecessary", "Recurring"]}`). `Model` needs:

```dart
final Map<String, List<String>>? tags;
```

Parsed in `fromJson` from the `tags` key.

#### `SetModelRequest` — add `tags` field

For assigning/clearing tags on create/update via `set_kgql_models`:

```dart
final List<SetModelTag>? tags;

class SetModelTag {
  final String system;
  final List<String> nodes;
  final bool clear;

  Map<String, dynamic> toJson() => {
    'system': system,
    'nodes': nodes,
    if (clear) 'clear': true,
  };
}
```

#### `SetModelTypeRequest` — add `tagSystems` field

For creating/editing/deleting tag systems via `set_kgql_model_types`:

```dart
final List<SetTagSystemRequest>? tagSystems;

class SetTagSystemRequest {
  final int? id;
  final String? name;
  final bool? isHierarchical;
  final String? selectionMode;
  final List<SetTagNodeRequest>? nodes;
  final bool delete;

  Map<String, dynamic> toJson();
}

class SetTagNodeRequest {
  final String name;
  final List<SetTagNodeRequest>? children;

  Map<String, dynamic> toJson();
}
```

### 3.3 New provider: `get_kgql_aggregate`

File: `nx_db/lib/src/data_providers/aggregate_provider.dart`

A generic helper function (not a cached provider, since params vary):

```dart
Future<Map<String, dynamic>> getKgqlAggregate(
  GraphQLClient client,
  Map<String, dynamic> filter,
  Map<String, dynamic> aggregate,
) async { ... }
```

### 3.4 Export new files from `nx_db.dart`

```dart
export 'src/models/TagSystem.dart';
export 'src/models/TagNode.dart';
export 'src/data_providers/aggregate_provider.dart';
```

---

## 4. App Screens & Features

### 4.1 Login (from `nx_db`)

Reuse `LoginPage` from `nx_db` as-is. Route: `/login`.

### 4.2 Home — Expense List (`/`)

The primary screen. Shows all Expense models.

**On load:**
1. Fetch Expense `ModelType` via `expenseSchemaProvider` (one-time, cached)
2. Build the `struct` dynamically from the schema:
   - Always include: `id`, `name`, `description`, `created_at`
   - For each attribute definition: add its `key` (e.g. `"cost": true`)
   - For each relation type: add `"<TargetModelType>": {"id": true, "name": true}`
   - Add `"tags": true` (fetches all tag systems, whatever they are)
3. Fetch expenses via `get_kgql_models` with that struct

**UI elements:**
- AppBar with title "Expenses", settings gear icon (→ tag systems management), and logout button
- Summary bar at top: total count + total spend
  - The aggregate key is the **first `number`-type attribute** from the schema (typically `cost`)
  - If no number attribute exists, just show count
- **Filter chips row** (scrollable horizontal):
  - "All" chip (always first)
  - For **each tag system** from the schema: one group of chips
    - If the system has few nodes (≤ 6): one chip per root node
    - If the system has many nodes: a single chip with the system name that opens a filter sheet
  - Tapping a chip applies `tag_filters: [{system: "<name>", node: "<node>", include_descendants: true}]`
- **ListView** of `ExpenseCard` widgets. Each card renders dynamically:
  - **Name** (bold, always)
  - **Primary number attribute** (right-aligned, formatted as currency) — first `number` attribute from schema
  - **Date** (`created_at`, formatted)
  - **Tag chips** — for each tag system, show assigned node names as colored chips
  - **Relation names** — for each relation type, show the related model's name in subtle text
- Pull-to-refresh (invalidates providers)
- FAB "+" to create new expense
- Tap a card → detail screen

**Sorting:** Most recent first (`created_at` descending, client-side sort).

### 4.3 Expense Detail (`/expense/:id`)

Full view of a single expense.

**Data source:** `get_kgql_models` with `filters: [{key: "id", op: "=", value: "<id>"}]` and the same dynamically-built struct as the list (but with full relation data).

**UI — all sections generated from schema:**

1. **Header** — name + primary number attribute (large)
2. **Date** — `created_at` formatted
3. **Description** — if present
4. **Attributes section** — for each `AttributeDefinition` in the schema:
   - Render a labeled row: `key → value` with type-appropriate formatting
   - Skip attributes already shown in header
5. **Tags section** — for each `TagSystem` in the schema:
   - Section header: system name
   - If hierarchical: show assigned node with breadcrumb path (e.g. "Food > Restaurants > Coffee")
   - If flat: row of chips for assigned nodes
   - If no nodes assigned: show "None" in muted text
6. **Relations section** — for each `RelationshipType` in the schema:
   - Section header: target model type name (e.g. "Company")
   - List of related model names, tappable (navigate to filtered expense list for that related model)
7. **Actions** — edit button (→ form), delete button (confirmation dialog)

### 4.4 Expense Form (`/expense/form` or `/expense/form/:id`)

Create or edit an expense. **All fields generated from schema.**

**Fixed fields:**
- Name (text field, required)
- Description (text field, optional)

**Dynamic attribute fields** — for each `AttributeDefinition` from the schema:
- Widget chosen by `value_type` (see §2.3 mapping table)
- Required flag from `attribute_definition.required`
- Label from `attribute_definition.key` (title-cased)

**Dynamic tag pickers** — for each `TagSystem` from the schema:
- Section header: system name
- If `selection_mode == "exclusive"`:
  - If `is_hierarchical`: tap to open tree picker (single select)
  - If flat: segmented button (if ≤ 4 nodes) or tap-to-open single-select list
- If `selection_mode == "multiple"`:
  - If `is_hierarchical`: tap to open tree picker (multi-select with checkboxes)
  - If flat: wrap of toggle chips
- Pre-filled with current values when editing

**Dynamic relation pickers** — for each `RelationshipType` from the schema:
- Section header: target model type name
- Tap to open `RelationPicker` bottom sheet:
  - Searches existing models of the target type via `get_kgql_models({model_type: "<target>"})`
  - Option to create new model inline
- Pre-filled with current linked models when editing

**Submit:**
```json
{
  "model_type": "Expense",          // only hardcoded value
  "name": "...",
  "attributes": [                   // built from dynamic fields
    {"key": "<attr_key>", "value": <user_input>}
  ],
  "tags": [                         // built from dynamic tag pickers
    {"system": "<system_name>", "nodes": ["<selected_node>", ...]}
  ],
  "relations": [                    // built from dynamic relation pickers
    {"model_type": "<target_type>", "link": [<selected_model_id>]}
  ]
}
```

For edit, prepend `"id": <expense_id>`.

### 4.5 Dashboard (`/dashboard`)

Aggregation visualizations. **Charts generated from schema.**

**Summary cards (top row):**
- For each `number`-type attribute: show SUM
  - `get_kgql_aggregate({model_type: "Expense"}, {metric: "sum", key: "<attr_key>"})`
- Always show: total count (`metric: "count"`)

**Dynamic charts:**

1. **Spend by Day** (always shown, bar chart)
   - `aggregate: {metric: "sum", key: "<first_number_attr>", group: {key: "created_at", window: "day"}}`

2. **One chart per tag system** (from schema):
   - For each `TagSystem`:
     - If hierarchical: two charts
       - Root level: `group: {key: "tag:<system_name>", level: 1}` (pie chart)
       - Leaf level: `group: {key: "tag:<system_name>"}` (horizontal bar chart)
     - If flat: one chart
       - `group: {key: "tag:<system_name>"}` (pie chart)
   - Chart title: "Spend by <system_name>"

3. **One chart per relation type** (from schema, if target type exists):
   - `group: {key: "<TargetType>.name"}` (pie chart)
   - Chart title: "Spend by <TargetType>"

**Filters:**
- Date range picker at the top to scope all charts

### 4.6 Tag Browser (`/tag-browser/:systemName`)

Interactive tree/list view for **any** tag system (not just "Category").

**Data source:** `expenseSchemaProvider` — find the tag system by name from the cached schema.

**UI:**
- If hierarchical: expandable tree of `TagTreeTile` widgets
  - Each tile: node name + expense count (via aggregate) + subtotal
  - Tapping a leaf → expense list filtered by that node
  - Tapping a parent → expand/collapse
- If flat: simple list of nodes with expense count + subtotal per node
- AppBar title: system name (e.g. "Category", "Judgment")

### 4.7 Tag Systems Management (`/tag-systems`)

List all tag systems for the Expense model type.

**Data source:** `expenseSchemaProvider` → `tagSystems`.

**UI:**
- List of tag systems, each showing:
  - Name
  - Selection mode badge (exclusive / multiple)
  - Hierarchical indicator icon
  - Node count
- Tap to edit → Tag System Form
- FAB "+" to create new tag system
- Swipe to delete (confirmation dialog) → `set_kgql_model_types` with `tag_systems: [{id: ..., delete: true}]`

### 4.8 Tag System Form (`/tag-system/form` or `/tag-system/form/:id`)

Create or edit a tag system and its nodes.

**Fields:**
- Name (text field, required)
- Selection mode (segmented button: exclusive / multiple)
- Is hierarchical (switch)
- **Nodes editor**:
  - If flat: reorderable list of text fields. "Add node" button.
  - If hierarchical: indented tree editor. Each node has name field + "Add child" button.
  - Existing nodes pre-filled; new nodes appended.

**Submit:** `set_kgql_model_types` with:
```json
{
  "id": <expense_model_type_id>,
  "name": "Expense",
  "type_kind": "base",
  "tag_systems": [{
    "id": <ts_id>,                    // omit for create
    "name": "...",
    "is_hierarchical": true/false,
    "selection_mode": "exclusive"/"multiple",
    "nodes": [
      {"name": "...", "children": [...]}  // recursive for hierarchical
    ]
  }]
}
```

After save, invalidate `expenseSchemaProvider` so the entire app picks up the new/changed tag system.

---

## 5. Navigation Structure

### Bottom Navigation (2 tabs)

| Tab | Icon | Screen |
|-----|------|--------|
| Expenses | `receipt_long` | Expense List (home) |
| Dashboard | `bar_chart` | Dashboard |

### Routes

| Path | Screen | Notes |
|------|--------|-------|
| `/login` | `LoginPage` (from nx_db) | Redirect here if unauthenticated |
| `/` | Home with bottom nav | Default tab: Expenses |
| `/expense/:id` | Expense Detail | Push from list |
| `/expense/form` | Expense Form (create) | Push from FAB |
| `/expense/form/:id` | Expense Form (edit) | Push from detail |
| `/tag-browser/:systemName` | Tag Browser | Push from dashboard or filter |
| `/tag-systems` | Tag Systems list | Push from settings gear |
| `/tag-system/form` | Tag System Form (create) | Push from tag systems list |
| `/tag-system/form/:id` | Tag System Form (edit) | Push from tag systems list |

---

## 6. Providers (Riverpod)

### Central schema provider

| Provider | Type | Purpose |
|----------|------|---------|
| `expenseSchemaProvider` | `FutureProvider<ModelType>` | Fetches Expense model type with `attributes`, `relations`, `tag_systems`. Cached; invalidated after tag system edits. All other providers depend on this. |

### Expense data providers

| Provider | Type | Purpose |
|----------|------|---------|
| `expenseStructProvider` | `Provider<Map<String, dynamic>>` | Derives the `struct` JSON from `expenseSchemaProvider` — used by list and detail queries |
| `expenseListProvider` | `FutureProvider.family<List<Model>, ExpenseFilter?>` | Fetches expenses with dynamic struct and optional tag/date filters |
| `expenseDetailProvider` | `FutureProvider.family<Model?, int>` | Single expense by ID with full dynamic struct |

### Aggregate providers

| Provider | Type | Purpose |
|----------|------|---------|
| `expenseSummaryProvider` | `FutureProvider` | SUM + COUNT using first number attribute |
| `spendByDayProvider` | `FutureProvider` | Aggregate grouped by day |
| `spendByTagSystemProvider` | `FutureProvider.family<..., String>` | Aggregate grouped by `tag:<systemName>` — called once per tag system |
| `spendByRelationProvider` | `FutureProvider.family<..., String>` | Aggregate grouped by `<RelationType>.name` — called once per relation type |

### Relation picker providers

| Provider | Type | Purpose |
|----------|------|---------|
| `relatedModelsProvider` | `FutureProvider.family<List<Model>, String>` | Fetches all models of a given type name (for relation pickers) |

### In `nx_db` (reusable)

| Provider / function | Purpose |
|---------------------|---------|
| `getKgqlAggregate()` | Generic aggregate helper function |
| `modelTypesProvider` | Already exists — can resolve "Expense" name → ID |
| `modelTypeProvider` | Already exists — fetch single model type with full struct |

---

## 7. Implementation Order

**Principle:** Ship **testable layers first** (pure Dart + `nx_db` + providers), then **UI**. Aligns with [`expense-test-cases.md`](./expense-test-cases.md) / [`expense-specific-test-cases.md`](./expense-specific-test-cases.md).

### Phase 1 — `nx_db` data layer (unit-testable, no UI)

1. Add `TagSystem`, `TagNode` with `fromJson` / `toJson`.
2. Extend `ModelType.fromJson` to parse `tag_systems`.
3. Extend `Model.fromJson` to parse `tags`.
4. Add `SetModelTag` to `SetModelRequest`; add `SetTagSystemRequest` / `SetTagNodeRequest` to `SetModelTypeRequest`.
5. Add `getKgqlAggregate()` helper (GraphQL query + JSON parse).
6. Export new symbols from `nx_db.dart`.
7. **Tests:** `nx_db/test/` — model parsing (fixtures), request `toJson`, aggregate helper mocks (see expense-specific cases **M***, **R***, **A***).

### Phase 2 — Struct + schema helpers (pure Dart, unit-testable)

8. Implement `buildExpenseStruct(ModelType)` (or equivalent) per §2.2 / §5 of this doc.
9. Implement helpers: `primaryNumberAttributeKey`, `tagSystemByName`, `allRelationTargetTypeNames`, `filterChipDescriptors` (or minimal subset first).
10. **Tests:** `nx_expense/test/` or `nx_db/test/` — struct snapshot / equality, helper edge cases (see **S***, **H***).

### Phase 3 — Riverpod providers + minimal app shell

11. Create `nx_expense` project (`pubspec` → `path: ../nx_db`).
12. Implement `expenseSchemaProvider`, `expenseStructProvider`, `expenseListProvider`, `expenseDetailProvider`, `expenseSummaryProvider`, `spendByDayProvider`, `spendByTagSystemProvider`, `spendByRelationProvider`, `relatedModelsProvider`.
13. Minimal `main.dart` + `router.dart`: login route + one **debug** screen or placeholder that reads a provider and prints / asserts (optional: integration test with `TestAuthController` like `nx_main/test/`).
14. **Tests:** mock GraphQL or provider overrides — **P*** cases; optional **I*** integration against live API.

### Phase 4 — Read-only expense UI

15. `ExpenseListScreen` — dynamic struct, `ExpenseCard`, pull-to-refresh.
16. `ExpenseDetailScreen` — sections driven by schema.
17. **Widget tests** (optional): card + detail with **mock** `Model` + schema.

### Phase 5 — Create / edit / delete expenses

18. `ExpenseFormScreen` + dynamic fields, `TagPicker`, `RelationPicker`.
19. Delete on detail; `set_kgql_models` delete path.

### Phase 6 — Dashboard + charts

20. `DashboardScreen` — summary cards from aggregate providers.
21. `fl_chart`: spend-by-day; one chart per tag system; one per relation type; date-range filter.

### Phase 7 — Filtering + tag browser

22. Dynamic filter chips on list (from tag systems).
23. `TagBrowserScreen` (`/tag-browser/:systemName`) — flat or hierarchical.

### Phase 8 — Tag system management UI

24. `TagSystemsScreen`, `TagSystemFormScreen` (node editor).
25. Delete tag system + **invalidate** `expenseSchemaProvider` after mutations.

---

## 8. Backend API Quick Reference

All calls go through PostGraphile GraphQL. `nx_db`'s `graphqlClientProvider` handles auth headers.

| Action | Function | Key params |
|--------|----------|------------|
| **Introspect Expense schema** | `get_kgql_model_type` | `model_types: ["Expense"], struct: {id, name, attributes, relations, tag_systems}` |
| List expenses | `get_kgql_models` | `filter: {model_type: "Expense"}`, struct built dynamically from schema |
| Expense detail | `get_kgql_models` | `filters: [{key: "id", op: "=", value: "..."}]`, same dynamic struct |
| Create expense | `set_kgql_models` | `{model_type: "Expense", name, attributes: [...], tags: [...], relations: [...]}` |
| Update expense | `set_kgql_models` | `{id: ..., attributes: [...], tags: [...], relations: [...]}` |
| Delete expense | `set_kgql_models` | `{id: ..., delete: true}` |
| Aggregate | `get_kgql_aggregate` | `{metric, key: "<dynamic_attr>", group: {key: "tag:<dynamic_system>"}}` |
| Filter by tag | `get_kgql_models` | `tag_filters: [{system: "<dynamic>", node: "<dynamic>", include_descendants}]` |
| Fetch tag systems | `get_kgql_model_type` | `model_types: [<expense_mt_id>], struct: {tag_systems: true}` |
| Create tag system | `set_kgql_model_types` | `{id: <mt_id>, tag_systems: [{name, nodes, ...}]}` |
| Edit tag system | `set_kgql_model_types` | `{id: <mt_id>, tag_systems: [{id: <ts_id>, name, nodes}]}` |
| Delete tag system | `set_kgql_model_types` | `{id: <mt_id>, tag_systems: [{id: <ts_id>, delete: true}]}` |
| List related models | `get_kgql_models` | `{model_type: "<dynamic_target_type>"}` — for relation pickers |

---

## 9. Seed Data Available

From `load_data.py`, the app will show out of the box (no manual data entry):

**13+ expenses** across Jan 1–7 2025:
- Coffee Meeting ($13), Hotel Stay ($150), Software License ($299), Team Lunch ($85), Starbucks ($8)
- Food budget ($40), Amusement park ($80), Fast Food ($12), Groceries ($120), Flights ($400), Gas ($45), Equipment ($120), Games ($60), Movies ($25)

**5 companies** (via `expense_for` relation): Acme Corporation, McDonalds, OpenAI, Airbnb, Starbucks

**3 tag systems** on Expense (all discovered dynamically):
- Category (hierarchical, exclusive) — 4 roots, 12 leaves
- Judgment (flat, multiple) — 4 nodes
- Essentiality (flat, exclusive) — 2 nodes

All expenses are pre-tagged. If a user adds a new tag system (e.g. "Priority" with nodes High/Medium/Low), the app immediately picks it up in the list, detail, form, dashboard, and filter UI without any code changes.
