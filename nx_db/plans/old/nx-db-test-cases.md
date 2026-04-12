# `nx_db` tests — overview (`mobile/nx_db/test/`)

Brief index of **what** to cover for the shared **`nx_db`** package: GraphQL client wiring, auth, JSON models, request DTOs, and Riverpod data providers. Use this file to plan coverage without rereading every source file.

**Scope boundary:** Correctness of SQL, RLS, and KGQL functions belongs in **`servers/pgdb/tests/`**. These tests focus on **Dart contracts**: parsing API JSON, building mutation payloads, provider variable shapes, and error propagation on the client.

**Specific cases:** Per-test IDs, fixtures, and expected values are in [`nx-db-specific-test-cases.md`](./nx-db-specific-test-cases.md).

---

## Scope

| Layer | What we exercise |
|--------|------------------|
| **Models** | `fromJson` / `toJson` (or `toJson`-only paths) for API-shaped maps; null/absent keys; snake_case vs camelCase where both appear |
| **Request DTOs** | `SetModelRequest`, `SetModelTypeRequest`, nested relation/tag payloads — round-trip to JSON expected by `set_kgql_*` docs |
| **Data providers** | Query/mutation **variable shapes**, parsing of string vs map GraphQL payloads, `FutureProvider` caching and failure modes |
| **Aggregate helper** | `getKgqlAggregate` + `parseKgqlAggregateResult` — scalar, grouped map, grouped list, errors |
| **Core / auth** | `graphqlClientProvider`, `AuthController`, presets — preferably with overrides or fakes; optional integration with live endpoint |
| **UI export** | `LoginPage` — widget or golden tests in app packages if desired; not required to live only in `nx_db/test/` |

---

## 1. Models — `Model` (`Model.dart`)

- **Identity**: `id`, `name`, `model_type_id` / `modelTypeId`, timestamps.
- **Attributes**: list form (`attributes` array) vs legacy flat map; `ModelAttribute` rows.
- **Relations**: `relations` array (`Relation`); type-specific capitalized keys (nested `Model` parse).
- **Tags**: `tags` map — system name → list of node strings; coexistence with attributes.
- **`toJson` / equality**: at least smoke coverage for round-trip or stable fields used by callers.

---

## 2. Models — `ModelType` (`ModelType.dart`)

- **Flat / list responses**: `id`, `name`, `type_kind`, `description`, `parentId`, `userId`.
- **Nested tree** (`get_kgql_model_type`): `parent`, `children`, `traits` recursively when `recursive: true`.
- **`AttributeDefinition`**: keys, `value_type`, `required`, `constraints`, delete flag in `toJson`.
- **`RelationshipType`**: `link` (id or name), multiplicity, `relation_attribute_definitions`, delete path.
- **`TagSystem`**: `tag_systems` array — coexistence with `attributes` and `relations`.

---

## 3. Models — `TagSystem` / `TagNode`

- **Flat vs hierarchical** nodes; `selection_mode`, `is_hierarchical`; `sort_order` if present.
- **Leaf helpers** (e.g. `leafNames`) for UI consumption.
- **`toJson`**: for editor / debug payloads.

---

## 4. Models — `TranscriptMessage` (`transcript_message.dart`)

- Parse and serialize messages used by transcript features (fields per current type).
- **Regression**: changes to backend field names do not silently drop data.

---

## 5. Request models — `SetModelRequest` and nested types

- **Core fields**: `id`, `model_type`, `name`, `description`, `traits`.
- **`ModelAttribute`**: create/update vs `delete: true`.
- **`ModelRelation`**: `link`, `create`, `delete`, nested `RelationAttribute`.
- **`SetModelTag`**: `system`, `nodes`, `clear` when applicable.

---

## 6. Request models — `SetModelTypeRequest` and nested types

- **Core**: `id`, `name`, `type_kind`, `description`, `parent` (`ParentLink`).
- **`AttributeDefinition`** / **`RelationshipType`** / **`RelationAttributeDefinition`**: create, update, delete branches in `toJson`.
- **`SetTagSystemRequest` / `SetTagNodeRequest`**: create vs edit vs `delete: true`; nested `children`.

---

## 7. Data providers — `models_provider.dart`

| Surface | Behaviors to test |
|--------|-------------------|
| **`modelsProvider` / `modelProvider`** | `getKgqlModels` variables (`filter`, `struct`); parse `string` vs list JSON; `Model.fromJson` list |
| **`createModel` / `updateModel`** | Mutation input shape; response extracts `id` from `setKgqlModels` JSON wrapper; error path |

---

## 8. Data providers — `model_types_provider.dart`

| Surface | Behaviors to test |
|--------|-------------------|
| **`modelTypesProvider`** | Empty `model_types` query; parse root list + `recursive` tree |
| **`modelTypeProvider`** | Query by id; `struct` includes `attributes`, `relations`, `tag_systems` as needed |
| **`createModelType` / `updateModelType`** | Mutation payload; `setKgqlModelTypes` response `id` extraction |

---

## 9. Data providers — `aggregate_provider.dart`

| Surface | Behaviors to test |
|--------|-------------------|
| **`getKgqlAggregate`** | GraphQL variables `filterkgql` + `aggregate`; maps through to client |
| **`parseKgqlAggregateResult`** | `null`; JSON string → object; raw `Map`; JSON array / grouped list → stable map shape; invalid types throw or document behavior |
| **Errors** | `QueryResult.hasException` → thrown exception propagates |

---

## 10. Data providers — `transcript_provider.dart`

- Provider(s) that fetch or mutate transcripts: **correct query/mutation names**, variable shapes, and parsing into `TranscriptMessage` (or list).
- **Caching / invalidation** if exposed (optional).

---

## 11. Core — `db.dart`, `auth.dart`, `backend_presets.dart`, `cf_access.dart`

| Surface | Behaviors to test |
|--------|-------------------|
| **`createClient` / `graphqlClientProvider`** | Headers (e.g. `x-user-id`); HTTPS upgrade for CF tunnels when applicable |
| **`AuthController`** | Login persists prefs; logout clears; `userIdProvider` / `endpointProvider` / `sockWsUrlProvider` / `imageBaseUrlProvider` |
| **`BackendPreset` / `resolve`** | Known presets → non-empty URLs; no duplicate keys in `PrefsKeys` usage |
| **`CfAccess`** | When `shouldAttachHeaders` / `endpointNeedsCfAccess` — headers attached (unit-level or mocked HTTP if added later) |

---

## 12. UI — `login_page.dart`

- **Optional in `nx_db`**: widget tests can live here or in **`nx_main`** / **`nx_expense`** with a small harness.
- **Minimum**: one smoke test that `LoginPage` builds with `ProviderScope` + `TestAuthController` override (if you want coverage inside this package).

---

## 13. Integration (optional)

- **`ProviderContainer` + `TestAuthController`** + real GraphQL (same pattern as **`nx_main/test/`**).
- **Gate** with an environment variable (e.g. `RUN_NX_DB_INTEGRATION=true`) so CI does not require a live server by default.
- **Assertions**: at least one successful `getKgqlModelType` or `getKgqlModels` parse end-to-end.

---

## Implementation checklist (for authors)

- [ ] Unit tests run **without** network unless explicitly gated by env.
- [ ] Prefer **fixtures** under `nx_db/test/fixtures/` for JSON blobs (model type, model row, aggregate responses).
- [ ] Cross-link new **specific** cases in [`nx-db-specific-test-cases.md`](./nx-db-specific-test-cases.md) when you add IDs.
- [ ] Do **not** duplicate `servers/pgdb/tests/**`; assert **Dart-side** contracts only.
- [ ] Mock **`GraphQLClient.query` / `mutate`** for provider tests; use **`ProviderContainer`** overrides for `graphqlClientProvider` and `authProvider` where appropriate.

---

## Related docs

| Doc | Role |
|-----|------|
| [`nx-db-specific-test-cases.md`](./nx-db-specific-test-cases.md) | Per-case IDs, inputs, expected outcomes for `nx_db` |
| [`expense-test-cases.md`](./expense-test-cases.md) | Expense app + shared `nx_db` expense-focused overlap |
| [`expense-specific-test-cases.md`](./expense-specific-test-cases.md) | Expense-specific IDs and fixtures |
| [`servers/pgdb/docs/human-reference/get_kgql_aggregate.md`](../../servers/pgdb/docs/human-reference/get_kgql_aggregate.md) | Aggregate JSON shapes (reference) |
