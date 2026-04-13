# Expense app tests — specific cases

Expands each block in [`expense-test-cases.md`](./expense-test-cases.md): **what** is under test, **inputs**, **expected** behavior. Intended to map 1:1 into `nx_expense/test/**` and `nx_db/test/**` (where parsing lives).

**Legend:** *Integration* = requires GraphQL + auth (optional suite). *Unit* = pure Dart, no I/O.

**ID prefix:** `M` = model parsing, `S` = struct building, `H` = schema helpers, `R` = request JSON, `P` = providers, `A` = aggregate helper, `I` = integration.

---

## 1. `TagSystem` / `TagNode` (`nx_db`)

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| M1.1 | Flat tag system | JSON: `id`, `name`, `is_hierarchical: false`, `selection_mode: multiple`, `nodes: [{id, name}, …]` | `TagSystem.fromJson` → `isHierarchical == false`, `nodes.length` matches, no `children` on nodes |
| M1.2 | Hierarchical tag system | `nodes: [{name: Food, children: [{name: Coffee}]}]` | Recursive parse; leaf has correct name |
| M1.3 | Snake_case keys | `is_hierarchical`, `selection_mode` | Mapped to Dart fields |
| M1.4 | Missing optional fields | No `model_type_id` | `modelTypeId` null; no throw |
| M1.5 | Empty `nodes` | `nodes: []` | `nodes` empty list |
| M1.6 | `TagNode.leafNames` (if implemented) | 3-level tree | Flat list of leaf names only |

---

## 2. `ModelType.fromJson` — `tag_systems`

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| M2.1 | `tag_systems` array | Full Expense introspection snippet with 2+ systems | `tagSystems!.length >= 2`; first system `name` matches |
| M2.2 | No `tag_systems` key | JSON without key | `tagSystems` null or `[]` per API convention |
| M2.3 | `tag_systems: null` | Explicit null | Same as M2.2 |

---

## 3. `Model.fromJson` — `tags`

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| M3.1 | Tags map | `"tags": {"Category": ["Coffee"], "Judgment": ["Unnecessary"]}` | `tags["Category"]` length 1; `tags["Judgment"]` length 1 |
| M3.2 | Empty tag list | `"tags": {"Category": []}` | Empty list for Category |
| M3.3 | No `tags` key | Model JSON without tags | `tags == null` |
| M3.4 | Coexists with `cost` | `cost` as top-level or in attributes per existing parser | `Model` still has id, name; tags present |

---

## 4. `SetModelTag` / `SetTagSystemRequest` / `SetTagNodeRequest`

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| R4.1 | `SetModelTag` minimal | `system: Category`, `nodes: [Coffee]` | JSON `{"system":"Category","nodes":["Coffee"]}` |
| R4.2 | `SetModelTag` + clear | `clear: true`, `nodes: []` | Includes `"clear": true` |
| R4.3 | `SetTagSystemRequest` create | No `id`, `name`, `nodes` flat | No `id` in JSON |
| R4.4 | `SetTagSystemRequest` delete | `id: 5`, `delete: true` | JSON has id + delete |
| R4.5 | `SetTagNodeRequest` nested | `children` 2 levels | JSON mirrors tree |

---

## 5. Struct building (`buildExpenseStruct` or equivalent)

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| S5.1 | Attributes only | Schema with `cost` (number), `note` (string) | Struct contains `"cost": true`, `"note": true` |
| S5.2 | Relations | Schema with relation to `Company` | Struct contains `"Company": {"id": true, "name": true}` (or agreed shape) |
| S5.3 | Tags shorthand | Any schema with tag systems | `"tags": true` present |
| S5.4 | Base model fields | — | `id`, `name`, `description`, `created_at` true as per `expense_app.md` |
| S5.5 | Empty attributes | No attribute definitions | No stray keys; still base + tags |
| S5.6 | Determinism | Same schema twice | Equal maps (key sets equal; use `DeepCollectionEquality` if order differs) |

---

## 6. Schema helpers

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| H6.1 | `primaryNumberAttributeKey` | Attributes: `[age string, cost number]` | `"cost"` |
| H6.2 | `primaryNumberAttributeKey` — none | Only string attrs | `null` |
| H6.3 | `primaryNumberAttributeKey` — first wins | Two number attrs | First in list order (document rule) |
| H6.4 | `tagSystemByName` | Schema with `Judgment` | Returns non-null; `name == Judgment` |
| H6.5 | `tagSystemByName` — missing | Unknown name | `null` |
| H6.6 | `allRelationTargetTypeNames` | Relations to Company, Place | Set `{Company, Place}` |
| H6.7 | `filterChipDescriptors` | Category tree with roots Food, Travel | At least one descriptor per root for quick filters (document max chips rule) |

---

## 7. Providers (`nx_expense`) — unit (mocked client)

Use **mocked** `GraphQLClient` or override providers to return fixed `ModelType` / JSON.

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| P7.1 | `expenseStructProvider` | Mock `expenseSchemaProvider` with fixture | Derived struct matches S5.* expectations |
| P7.2 | `expenseListProvider` — no filter | Mock client returns JSON array | `List<Model>` length; each `modelTypeId` matches Expense |
| P7.3 | `expenseListProvider` — tag filter | `ExpenseFilter` with one `tag_filters` entry | Query variables include `tag_filters` |
| P7.4 | `expenseDetailProvider` | id `42` | Filter DSL includes `id` eq `42` |
| P7.5 | `expenseSummaryProvider` | Schema with number key `cost` | Aggregate uses `key: cost` not hardcoded in provider source (verify via mock capture) |
| P7.6 | `spendByTagSystemProvider("Category")` | — | `group` key contains `tag:Category` |
| P7.7 | `spendByRelationProvider("Company")` | — | Group key `Company.name` or documented alternate |
| P7.8 | `relatedModelsProvider("Company")` | — | Filter `model_type: Company` |
| P7.9 | Schema invalidation | After `invalidate(expenseSchemaProvider)` | `expenseStructProvider` recomputes (second read differs if mock changes) |

---

## 8. `getKgqlAggregate` (`nx_db`)

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| A8.1 | Happy path | Mock returns `{ "getKgqlAggregate": "{\"aggregated_value\": 1457}" }` or parsed object | Function returns numeric total |
| A8.2 | Grouped result | Mock returns grouped array JSON | Parser returns list/map usable by dashboard |
| A8.3 | GraphQL error | Mock throws | Exception propagates |

---

## 9. Integration (optional) — live backend

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| I9.1 | Expense schema load | `TestAuthController` + real client | `model_type: Expense` has `attributes` non-empty |
| I9.2 | Tag systems present | Same | `tag_systems` in raw JSON or `tagSystems` on `ModelType` length ≥ 1 |
| I9.3 | List expenses | `expenseListProvider` | `length > 0` with seed DB |

---

## 10. Edge cases

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| E10.1 | Malformed `tags` value | Non-list value for a system key | Parser skips or fails gracefully (document choice) |
| E10.2 | Very deep tag tree | 4 levels | No stack overflow; all nodes reachable |
| E10.3 | Unicode / spaces in node names | `"name": "Café ☕"` | Round-trip string equality |
| E10.4 | Concurrent provider reads | Two widgets read `expenseStructProvider` | Same instance (Riverpod cache) |

---

## Cross-reference

| `expense-test-cases.md` § | This doc sections |
|---------------------------|-------------------|
| §1 TagSystem/TagNode | §1 |
| §2 ModelType | §2 |
| §3 Model tags | §3 |
| §4 Set* requests | §4 |
| §5 Struct | §5 |
| §6 Helpers | §6 |
| §7 Providers | §7 |
| §8 getKgqlAggregate | §8 |
| §9 Integration | §9 |
| §10 Widgets | (use §7 + widget-specific rows in app test files) |

---

## Related

- [`expense-test-cases.md`](./expense-test-cases.md) — overview and scope  
- [`expense_app.md`](./expense_app.md) — architecture  
- `servers/pgdb/tests/test_tags.py` — backend tag behavior (do not duplicate)
