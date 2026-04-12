# Expense app tests — overview (`nx_expense/test/`, `nx_db/test/`)

Brief index of **what** to cover for the Flutter expense app and `nx_db` support code. Full inputs and expectations live in [`expense-specific-test-cases.md`](./expense-specific-test-cases.md). Use this file to plan test files so coverage stays visible without rereading [`expense_app.md`](./expense_app.md).

**Scope boundary:** Backend correctness (`get_kgql_models`, tags, aggregates, RLS) is covered by `servers/pgdb/tests/` (e.g. `test_tags.py`). These tests focus on **Dart parsing**, **struct derivation**, **request JSON**, and **Riverpod providers** in the mobile stack.

---

## Scope

| Layer | What we exercise |
|--------|------------------|
| **`nx_db` models** | `TagSystem` / `TagNode` JSON; `ModelType.tagSystems`; `Model.tags`; `SetModelRequest.tags`; `SetModelTypeRequest.tagSystems` |
| **Struct building** | Pure functions that map `ModelType` (Expense schema) → `struct` map for `get_kgql_models` |
| **Schema helpers** | First number attribute; tag system lookup by name; relation target names; filter chip generation |
| **`getKgqlAggregate` (nx_db)** | Parses JSON result; error propagation |
| **Providers (`nx_expense`)** | `expenseSchemaProvider`, `expenseStructProvider`, list/detail/summary/aggregate families, `relatedModelsProvider` |
| **Integration (optional)** | `ProviderContainer` + `TestAuthController` + live GraphQL — same pattern as `nx_main/test/` |

---

## 1. `nx_db` — `TagSystem` / `TagNode`

- **Parse** backend keys: `is_hierarchical`, `selection_mode`, `tag_systems`, nested `nodes` / `children`.
- **Flat systems**: nodes without `children` (or empty).
- **Hierarchical**: 2+ levels; preserve order / `sort_order` if present.
- **Round-trip**: `toJson` → `fromJson` where applicable (for editor payloads).

---

## 2. `nx_db` — `ModelType.fromJson`

- **`tag_systems` present**: populates `tagSystems` list.
- **`tag_systems` absent / null**: `tagSystems` is null or empty list per convention.
- **Coexistence**: `attributes`, `relations`, `tagSystems` all parse without dropping fields.

---

## 3. `nx_db` — `Model.fromJson` — `tags`

- **`tags` as map** of system name → list of node names (strings).
- **`tags` absent**: `tags` null.
- **Mixed with EAV**: attributes still parse when `tags` present.
- **Legacy flat keys**: existing `Model.fromJson` behavior for non-tag keys unchanged.

---

## 4. `nx_db` — `SetModelRequest` / `SetModelTypeRequest`

- **`SetModelTag.toJson`**: `system`, `nodes`, optional `clear`.
- **`SetTagSystemRequest` / `SetTagNodeRequest`**: create vs edit vs delete (`delete: true`); nested `children`.

---

## 5. Struct building (pure Dart, `nx_expense` or `nx_db`)

**Input:** `ModelType` for Expense (from introspection). **Output:** `Map<String, dynamic>` for GraphQL `struct`.

- **Base fields**: `id`, `name`, `description`, `created_at` (and `updated_at` if required by UI).
- **Attributes**: for each `AttributeDefinition`, add `"<key>": true`.
- **Relations**: for each outgoing relation, add `"<TargetModelTypeName>": { id: true, name: true }` (shape per `expense_app.md`).
- **Tags**: always `"tags": true` (or explicit per-system map if product requires named projection only).
- **Stability**: same schema → same struct keys (order may be canonicalized for tests).

---

## 6. Schema-derived helpers

| Helper | Role |
|--------|------|
| `primaryNumberAttributeKey(schema)` | First `value_type == number` attribute key, or null |
| `tagSystemByName(schema, name)` | Returns `TagSystem` or null |
| `allRelationTargetTypeNames(schema)` | Distinct target types for relation pickers / group keys |
| `filterChipDescriptors(schema)` | List of `{ systemName, nodeName, includeDescendants }` for quick filters (rules in specific doc) |

---

## 7. Providers (`nx_expense`)

| Provider | Behaviors to test |
|----------|-------------------|
| **`expenseSchemaProvider`** | Calls `get_kgql_model_type` with `model_types: ["Expense"]` and full struct; caches; **invalidation** after tag-system mutation (manual or mocked) |
| **`expenseStructProvider`** | Sync derive from schema; **throws or empty** if schema not loaded |
| **`expenseListProvider`** | Merges `filter: { model_type: "Expense" }` + dynamic struct + optional `ExpenseFilter` (tags, dates) |
| **`expenseDetailProvider`** | `filters` on `id`; same struct as list |
| **`expenseSummaryProvider`** | Uses `primaryNumberAttributeKey` for SUM; COUNT without assuming attribute name `"cost"` |
| **`spendByDayProvider`** | `group: created_at` + `window: day` + metric key from schema |
| **`spendByTagSystemProvider(systemName)`** | `group: tag:<name>`; optional `level` for hierarchical |
| **`spendByRelationProvider(targetTypeName)`** | `group: <TargetType>.name` |
| **`relatedModelsProvider(targetTypeName)`** | `get_kgql_models` with `model_type: <name>` |

---

## 8. `getKgqlAggregate` (`nx_db`)

- Successful parse of `aggregated_value` / grouped array (match PostGraphile shape).
- Passes through filter + aggregate maps unchanged.
- GraphQL errors surface as thrown exceptions (or `Result` type if you add one).

---

## 9. Widget tests (optional, `nx_expense/test/widgets/`)

- **`ExpenseCard`**: given a `Model` + schema, shows title + primary number + tag chips.
- **`TagPicker`**: exclusive vs multiple; hierarchical vs flat — **mock** `TagSystem` only.

---

## 10. Integration tests (optional, `nx_expense/test/integration/`)

- Same pattern as `nx_main/test/get_model_type_test.dart`: `TestAuthController`, real endpoint.
- **Minimal assertions**: Expense schema has `tagSystems` length ≥ 1; list provider returns non-empty with seed DB.

---

## Implementation checklist (for authors)

- [ ] Unit tests run **without** network (`flutter test test/models`, `test/struct`, `test/providers` with mocks).
- [ ] Cross-link each test group back to **§** in [`expense-specific-test-cases.md`](./expense-specific-test-cases.md).
- [ ] Do **not** duplicate `test_tags.py` scenarios; only assert **Dart-side** contracts and provider wiring.
- [ ] Prefer **golden JSON fixtures** under `test/fixtures/` for `ModelType` / `Model` samples.

---

## Related docs

| Doc | Role |
|-----|------|
| [`expense-specific-test-cases.md`](./expense-specific-test-cases.md) | Per-case IDs, inputs, expected outcomes |
| [`expense_app.md`](./expense_app.md) | Product architecture and provider list |
| [`servers/pgdb/docs/current-plans/tags/test-cases.md`](../../servers/pgdb/docs/current-plans/tags/test-cases.md) | Backend tag tests (reference only) |
