# `nx_db` tests — specific cases

Expands each section in [`nx-db-test-cases.md`](./nx-db-test-cases.md): **what** is under test, **inputs**, **expected** behavior. Intended to map into `mobile/nx_db/test/**` (and optionally app packages for `LoginPage`).

**Legend:** *Integration* = GraphQL + auth (optional, env-gated). *Unit* = pure Dart / mocked `GraphQLClient`. Backend SQL/RLS remains in `servers/pgdb/tests/`.

**Overlap:** Tag / Expense-focused rows already spelled out in [`expense-specific-test-cases.md`](./expense-specific-test-cases.md) are **cross-referenced** here (`→ expense §…`) so we do not fork two sources of truth for the same assertion.

**ID prefixes:** `MD` = `Model`, `MT` = `ModelType`, `TG` = `TagSystem`/`TagNode`, `TR` = transcript models, `RS` = `SetModelRequest`, `RT` = `SetModelTypeRequest`, `PM` = `models_provider`, `PT` = `model_types_provider`, `AG` = aggregate helper, `PX` = transcript service, `CR` = core (`db`/`auth`/`presets`/`cf`), `LP` = `LoginPage`, `IN` = integration, `E` = edge/regression.

---

## 1. `Model` (`Model.dart`)

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| MD1.1 | Identity + `model_type_id` | JSON with `id`, `name`, `model_type_id` | Fields match; `modelTypeId` set |
| MD1.2 | CamelCase `modelTypeId` | `modelTypeId` instead of snake | Same as MD1.1 |
| MD1.3 | Timestamps | `created_at` / `updated_at` | `createdAt` / `updatedAt` populated |
| MD1.4 | Attributes as array | `attributes: [{id, key, value}, …]` | `attributesList` non-null; map built for compatibility |
| MD1.5 | Attributes as map | `attributes: {k: v}` | `attributes` map |
| MD1.6 | Legacy flat keys | Extra keys not in skip-list | Folded into `attributes` when not relations |
| MD1.7 | `relations` array | `relations: [{relation_id, model_id, model_type, …}]` | `relationsList` length matches |
| MD1.8 | Type-specific relation keys | `"Company": [{…}]` capitalized | `relations['Company']` parses nested `Model`s |
| MD1.9 | `tags` | See expense §3 | → expense **M3.*** |
| MD1.10 | `toJson` smoke | Construct or parse then `toJson` | Contains `id`, `name`, `modelTypeId` at minimum |
| MD1.11 | `relationsByModelType` | `relationsList` with mixed `modelType` | Grouping map keys match relation targets |

---

## 2. `ModelType` (`ModelType.dart`)

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| MT2.1 | Flat root | `id`, `name`, `type_kind` | `typeKind` set |
| MT2.2 | Snake + camel | `type_kind` vs `typeKind` | Either maps to `typeKind` |
| MT2.3 | `parent` node | `parent: {id, name}` | `parent` non-null; `parentId` inferred if absent |
| MT2.4 | `children` + `recursive` | Children with nested fields | Child `ModelType`s parsed; `parentId` injected |
| MT2.5 | `traits` | Traits list | Same pattern as children |
| MT2.6 | `attributes` | List of attr maps | `AttributeDefinition` list; `key`, `value_type`, `required` |
| MT2.7 | `relations` | `target_model_type` + nested attrs | `RelationshipType` with `link` = name |
| MT2.8 | `tag_systems` | See expense §2 | → expense **M2.*** |
| MT2.9 | `toJson` round-trip smoke | Minimal populated `ModelType` | Emits `id`, `name`, nested keys when non-null |
| MT2.10 | `AttributeDefinition.toJson` delete | `delete: true`, `id` set | Only `id` + `delete: true` |
| MT2.11 | `RelationshipType.toJson` delete | `delete: true` | Only `id` + `delete: true` |
| MT2.12 | Relation attr definitions | `relation_attribute_definitions` in relation | Nested list in JSON |

---

## 3. `TagSystem` / `TagNode`

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| TG3.x | Core tag parse / leafNames / SetTag payloads | — | → expense **§1 (M1.*)** and **§4 (R4.*)** |
| TG3.1 | `TagSystem.toJson` | Instance with `nodes` | `tag_systems`-shaped map (snake_case keys per implementation) |
| TG3.2 | `TagNode.toJson` nested | Children present | Recursive `children` arrays |

---

## 4. `TranscriptMessage` / `Transcript` (`transcript_message.dart`)

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| TR4.1 | `TranscriptMessage.fromJson` | `timestamp`, `sender`, `message` | All fields; `isFromUser` true when sender `Human` |
| TR4.2 | `TranscriptMessage.toJson` | Constructed instance | Round-trip equality on fields |
| TR4.3 | `Transcript.fromJson` | `id`, `messages: {ts: {sender, message}}` | `messages` map keyed by timestamp; nested `TranscriptMessage` |
| TR4.4 | `sortedMessages` | Unordered keys | Sorted by timestamp string |
| TR4.5 | `copyWithMessage` | Add second message | Length + contains both timestamps |

---

## 5. `SetModelRequest` and nested types (`SetModelRequest.dart`)

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| RS5.x | `SetModelTag` | — | → expense **R4.1–R4.2** |
| RS5.1 | Minimal create | `modelType`, `name`, `attributes` | `toJson` has `model_type`, `name`, `attributes` |
| RS5.2 | Update with `id` | `id` set | `id` in JSON |
| RS5.3 | `ModelAttribute` delete | `delete: true` | `key` + `delete: true` only |
| RS5.4 | `ModelRelation` link | `modelType` + `link: [1,2]` | `link` array in JSON |
| RS5.5 | `ModelRelation` delete | `delete: true` | Short JSON per implementation |
| RS5.6 | `RelationAttribute` | Nested on relation | `attributes` under relation |

---

## 6. `SetModelTypeRequest` and nested types (`SetModelTypeRequest.dart`)

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| RT6.x | Tag systems | — | → expense **R4.3–R4.5** |
| RT6.1 | Minimal create | `name`, `type_kind` | `name`, `type_kind` in JSON |
| RT6.2 | `ParentLink` | `ParentLink.fromName("X")` | `parent: {link: X}` or per doc |
| RT6.3 | `attribute_definitions` array | One `AttributeDefinition` create | `attribute_definitions` in JSON |
| RT6.4 | `relationship_types` | One `RelationshipType` with name link | `relationship_types` present |
| RT6.5 | `AttributeDefinition` delete | `delete: true` + `id` | Delete shape |

---

## 7. `models_provider.dart`

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| PM7.1 | `getKgqlModels` variables | Mock capture | `filter` contains `model_type` (name or id per impl); `struct` present |
| PM7.2 | String JSON response | `getKgqlModels` returns stringified array | `json.decode` → list of `Model` |
| PM7.3 | List response | Native JSON array | Same parse path |
| PM7.4 | `modelProvider` filter shape | `filters` with `id` op `=` | Variables match [`models_provider`](../../nx_db/lib/src/data_providers/models_provider.dart) |
| PM7.5 | `createModel` mutation vars | `SetModelRequest.toJson` | Wrapped in `input.data` per PostGraphile pattern |
| PM7.6 | `createModel` response | `setKgqlModels` returns `{json: "{\"id\": 5}"}` | Returns `5` |
| PM7.7 | Mutation exception | `result.hasException` | Throws / propagates |

---

## 8. `model_types_provider.dart`

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| PT8.1 | `getAllModelTypes` query | `model_types: []` in input | Empty array returns roots |
| PT8.2 | Parse roots | Multiple root nodes | `ModelType.fromJson(..., recursive: true)` |
| PT8.3 | `modelTypeProvider` by id | `struct` includes `tag_systems` when present in query | Parsed `tagSystems` on result |
| PT8.4 | `createModelType` response | `json` field string | Parsed `id` int |
| PT8.5 | `updateModelType` requires id | `SetModelTypeRequest` without `id` | Throws before network (if enforced) |

---

## 9. `aggregate_provider.dart`

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| AG9.x | Parser + client + errors | — | Align with expense **§8 (A8.*)** / existing `aggregate_provider_test.dart` |
| AG9.1 | Variable names | Mock `query` | Variables include `filterkgql` and `aggregate` (GraphQL field names) |
| AG9.2 | Scalar string payload | `getKgqlAggregate` string JSON object | `aggregated_value` in map |
| AG9.3 | Grouped list payload | Array JSON string | `parseKgqlAggregateResult` → `grouped` list (per implementation) |

---

## 10. Transcript service (`transcript_provider.dart` / `TranscriptService`)

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| PX10.1 | `getCurrentTranscript` query name | Inspect `QueryOptions` | Document contains `getCurrentTranscript`; `userIdParam` variable |
| PX10.2 | Parse transcript JSON | Mock `data` shape | `Transcript?` with expected `id` |
| PX10.3 | Unauthenticated path | Missing prefs | Throws “not authenticated” (or current message) |
| PX10.4 | `addMessageToTranscript` mutation | — | Mutation document + `input` wrapper |

*(Subscription paths optional if not unit-tested.)*

---

## 11. Core — `db.dart`, `auth.dart`, `backend_presets.dart`, `cf_access.dart`

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| CR11.1 | `createClient` HTTP header | Endpoint + userId | Default headers include `x-user-id` |
| CR11.2 | CF HTTP→HTTPS | Host that `CfAccess.endpointNeedsCfAccess` treats as CF | `https://` used in client (mock or spy if needed) |
| CR11.3 | `BackendPreset.fromKey` | Known keys | Non-null preset |
| CR11.4 | `resolve(preset)` | Each preset in enum | `graphqlHttp`, `sockWs`, `imageHttp` non-empty strings |
| CR11.5 | `AuthController.login` | Valid userId + preset | Writes `PrefsKeys` (userId, endpoint, preset, sock) |
| CR11.6 | `AuthController.logout` | After login | Clears stored keys |
| CR11.7 | `userIdProvider` | Logged-in user | Returns userId string |
| CR11.8 | `appStatusProvider` | Loading vs data | `initializing` vs `authenticated` / `unauthenticated` |

---

## 12. `login_page.dart`

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| LP12.1 | Builds under `ProviderScope` | `TestAuthController` + `MaterialApp` | No throw; finds form widgets (or smoke) |
| LP12.2 | Successful login callback | `onLoginSuccess` | Invoked with resolved URLs when login succeeds (mock auth) |

*(Prefer minimal tests in `nx_db`; full golden/navigation can stay in `nx_main` / `nx_expense`.)*

---

## 13. Integration (optional)

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| IN13.1 | Live `getKgqlModelType` | `RUN_NX_DB_INTEGRATION=true`, `TestAuthController`, real preset | Returns non-empty JSON; parses to `ModelType` |
| IN13.2 | Live `getKgqlModels` | Same + filter | At least zero or more rows; no parse exception |
| IN13.3 | Live aggregate | `getKgqlAggregate` with minimal filter | Map or grouped shape parseable |

Gate all **IN13.*** on **`RUN_NX_DB_INTEGRATION=true`** (or project-standard env name) so default CI skips.

---

## 14. Edge / regression (cross-cutting)

| ID | What it tests | Input | Expected |
|----|----------------|-------|----------|
| E14.1 | Unknown GraphQL field in JSON | Extra keys in model map | Ignored or preserved per policy; no crash |
| E14.2 | Large nested `Model` tree | Deep relation nesting | Stack safe; parses |

---

## Cross-reference

| [`nx-db-test-cases.md`](./nx-db-test-cases.md) § | This doc sections |
|-----------------------------------------------|-------------------|
| §1 Model | §1 (MD*) |
| §2 ModelType | §2 (MT*) |
| §3 TagSystem/TagNode | §3 (TG*) + expense §1–2 |
| §4 Transcript | §4 (TR*) |
| §5 SetModelRequest | §5 (RS*) |
| §6 SetModelTypeRequest | §6 (RT*) |
| §7 models_provider | §7 (PM*) |
| §8 model_types_provider | §8 (PT*) |
| §9 aggregate | §9 (AG*) |
| §10 transcript service | §10 (PX*) |
| §11 core | §11 (CR*) |
| §12 LoginPage | §12 (LP*) |
| §13 integration | §13 (IN*) |

---

## Related docs

| Doc | Role |
|-----|------|
| [`nx-db-test-cases.md`](./nx-db-test-cases.md) | High-level map |
| [`expense-specific-test-cases.md`](./expense-specific-test-cases.md) | Expense + tag overlap |
| [`servers/pgdb/docs/human-reference/`](../../servers/pgdb/docs/human-reference/) | API shapes for fixtures |
