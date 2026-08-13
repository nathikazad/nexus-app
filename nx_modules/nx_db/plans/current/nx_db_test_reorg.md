# `nx_db` test suite reorganization plan

Companion to [`nx_db_reorg.md`](./nx_db_reorg.md). The `lib/` reorg landed; the
test suite still mirrors the **old** structure (and several files no longer
compile because they import paths that were deleted). This document records
where coverage stands today and how to restructure the suite so it mirrors
`lib/src/` and tests each layer in isolation.

## Where the suite stands today

### Coverage by surface area (post-reorg `lib/src/` → existing tests)

| New `lib/src/` location | Test file(s) today | Coverage quality |
|---|---|---|
| `core/client/graphql_client.dart` (`createClient`) | none directly | **gap** — only exercised transitively through providers |
| `core/client/graphql_client_provider.dart` | overridden in many tests, never asserted | smoke only |
| `core/config/backend_presets.dart` | `unit/core_auth_db_test.dart` (CR11.3, CR11.4) | adequate |
| `core/config/cf_access.dart` | `unit/core_auth_db_test.dart` (CR11.2) | one-liner, partial |
| `core/config/graphql_http_config.dart` | `unit/core_auth_db_test.dart` (CR11.1) | one-liner |
| `core/json/json_coercion.dart` | none (helpers are still private/internal) | **gap** — extracting them was a stated motivation of the reorg |
| `core/json/payload_unwrap.dart` | implicitly tested via `parseKgqlModelsResult` and `parseKgqlAggregateResult` | **gap** — no direct tests of the unified helper |
| `auth/user.dart` | none | **gap** |
| `auth/auth_controller.dart` | `unit/core_auth_db_test.dart` (CR11.5–8) | good for happy path; no error paths, no ping retry |
| `auth/auth_providers.dart` | same | good |
| `auth/backend_ping.dart` | none (always skipped) | **gap** |
| `auth/login_page.dart` | `widget/login_page_test.dart` (LP12.1–2) | adequate |
| `kgql/documents/*.graphql.dart` | only `getCurrentTranscriptQuery` / `addMessageToTranscriptMutation` (PX10.1, PX10.4) | **gap** — no `gql()` parse smoke for the rest |
| `kgql/models/model.dart` | `unit/model_test.dart`, `model_tags_test`, `model_tags_edge_test` | strong |
| `kgql/models/model_type.dart` | `unit/model_type_test.dart`, `model_type_tags_test` | strong |
| `kgql/models/attribute.dart` | covered indirectly by model / model_type tests | partial — no dedicated file |
| `kgql/models/relation.dart` (`Relation`, `RelationshipType`, `RelationAttributeDefinition`) | `model_type_test.dart` MT2.7/2.10–12 | partial |
| `kgql/models/tag_node.dart`, `tag_system.dart` | `unit/tag_system_test.dart`, `tag_system_tojson_test.dart` | strong |
| `kgql/requests/set_model_request.dart` | `unit/set_model_request_extended_test.dart` | strong |
| `kgql/requests/set_model_type_request.dart` | `unit/set_model_type_request_extended_test.dart`, `set_requests_test.dart` | strong |
| `kgql/repositories/models_repository.dart` | none directly — only via `providers/models_provider_test.dart` | **gap** — repository is the new pure-Dart unit; should be tested without Riverpod |
| `kgql/repositories/model_types_repository.dart` | none directly — only via providers | **gap** |
| `kgql/repositories/aggregate_repository.dart` | `providers/aggregate_provider_test.dart` (mis-named — there is no provider) | OK content, wrong location/name |
| `kgql/providers/models_providers.dart` | `providers/models_provider_test.dart` (PM7.1–7) | OK but mixes provider wiring + GraphQL shape |
| `kgql/providers/model_types_providers.dart` | `providers/model_types_provider_test.dart` (PT8.*) | OK |
| `kgql/providers/relation_picker_providers.dart` | none | **gap** |
| `transcript/transcript.dart` | `unit/transcript_message_test.dart` (TR4.*) | strong |
| `transcript/transcript_repository.dart` | `providers/transcript_service_test.dart` (PX10.*) | partial — no mocked-client query/mutate path |
| `transcript/transcript_providers.dart` | none directly | **gap** |
| `integration/` | `nx_db_integration_test.dart` (read + aggregate), `seed_data_schema_integration_test.dart` (schema vs seed) | reads only — **no write/CRUD round trip** |

### Things that are actively broken by the reorg

The suite will not compile until these stale `src/...` imports are repaired:

- `test/providers/models_provider_test.dart` imports `package:nx_db/src/models/requests/SetModelRequest.dart`
- `test/providers/aggregate_provider_test.dart` imports `package:nx_db/src/data_providers/aggregate_provider.dart`
- `test/providers/transcript_service_test.dart` imports `package:nx_db/src/data_providers/transcript_provider.dart`
- `test/integration/nx_db_integration_test.dart` imports `src/data_providers/{aggregate_provider,model_types_provider,models_provider}.dart`
- `test/integration/seed_data_schema_integration_test.dart` imports `src/data_providers/{model_types_provider,models_provider}.dart`

### Why the structure itself is wrong (not just stale paths)

1. The folders mirror the **old** `lib/` structure (`unit/` vs `providers/` vs
   `widget/`), not the new layered one (`core/`, `auth/`, `kgql/{models,
   requests, documents, repositories, providers}`, `transcript/`).
2. **Repositories are the new pure-Dart unit** but are tested only through
   Riverpod, so we can't isolate "is the GraphQL contract right?" from "is
   the provider wiring right?".
3. The duplication that the reorg deleted (`payload_unwrap`, `json_coercion`)
   has **zero direct tests**.
4. Documents are no longer collocated with the code that uses them, but no
   test guards their syntactic validity. A typo in a `.graphql.dart` file
   only blows up at runtime in a downstream app.
5. Integration tests cover read and aggregate paths but not write — a
   regression in `setModel` / `deleteModel` would not be caught here.

## Target layout — mirror `lib/src/` exactly

One test file per source file. Test at the lowest layer with logic; let
higher layers get only smoke / wiring tests. Reserve integration tests for
things only the live server can answer.

```
test/
  _support/
    mock_graphql_client.dart        # _MockGql, fallback registration, okQueryResult helpers
    riverpod_helpers.dart           # makeContainer({overrides}) helper

  core/
    client/
      graphql_client_test.dart      # createClient: x-user-id header, CF headers, ws link
    config/
      backend_presets_test.dart     # CR11.3 + key roundtrip + resolve(...)
      cf_access_test.dart           # CR11.2 + only-rewrite-cf-hosts edge
      graphql_http_config_test.dart # CR11.1 + extra header merge
    json/
      payload_unwrap_test.dart      # null|String|Map|{json:…}|List → canonical Map/List
      json_coercion_test.dart       # asJsonInt, parseOptionalStringField, etc. (promoted to public)

  auth/
    user_test.dart
    auth_controller_test.dart       # CR11.5–8 + login error path + logout invalidates client
    auth_providers_test.dart        # derivations of userIdProvider/endpointProvider/appStatusProvider
    backend_ping_test.dart          # mock http.Client → 200/4xx/timeout

  kgql/
    documents/
      kgql_documents_shape_test.dart   # gql() each doc; assert expected $vars exist exactly once
    models/
      model_test.dart                  # current MD1.*
      model_type_test.dart             # current MT2.*
      attribute_test.dart              # AttributeDefinition + ModelAttribute parsing/toJson
      relation_test.dart               # Relation, RelationshipType, RelationAttributeDefinition
      tag_node_test.dart
      tag_system_test.dart             # current tag_system_*
    requests/
      set_model_request_test.dart      # current set_model_request_extended_test
      set_model_type_request_test.dart # current set_model_type_request_extended_test
      set_tag_requests_test.dart       # current set_requests_test.dart
    repositories/                      # NEW LAYER — plain functions, mocked GraphQLClient
      models_repository_test.dart      # fetchKgqlModels/ById, setModel, deleteModel
      model_types_repository_test.dart # fetchByName, listAll, setModelType
      aggregate_repository_test.dart   # current aggregate_provider_test, moved + renamed
    providers/                         # thin Riverpod wiring tests only
      models_providers_test.dart       # family keying, invalidation, override composition
      model_types_providers_test.dart  # current PT8.*
      relation_picker_providers_test.dart

  transcript/
    transcript_test.dart               # current TR4.*
    transcript_repository_test.dart    # parse + fetch via mocked client (was PX10.2)
    transcript_providers_test.dart     # Riverpod wiring; unauth throws (was PX10.3)

  widget/
    login_page_test.dart               # unchanged (will eventually move to nx_auth_ui)

  integration/                         # only RUN_NX_DB_INTEGRATION=true
    seed_data_schema_integration_test.dart
    read_paths_integration_test.dart   # rename of nx_db_integration_test.dart
    crud_round_trip_integration_test.dart   # NEW — create→get→update→delete an Expense
    transcript_subscription_integration_test.dart  # NEW — subscribe + add message
```

### Updated `dart_test.yaml`

```yaml
tags:
  unit:        { description: "Pure model / request / json-coercion tests" }
  repository:  { description: "KGQL repositories with mocked GraphQLClient" }
  provider:    { description: "Riverpod wiring around repositories" }
  auth:        { description: "AuthController + providers (mocked SharedPreferences)" }
  widget:      { description: "Flutter widget tests (LoginPage)" }
  integration: { description: "Live GraphQL — also requires RUN_NX_DB_INTEGRATION=true" }
```

## Coverage gaps that need new tests (priority order)

1. **`core/json/payload_unwrap_test.dart`** — the entire reason for extracting
   that helper. Cover every shape `getKgqlModels` / `getCurrentTranscript` /
   `setKgqlModels` can return: `null`, JSON string, `Map`, `{json: "<string>"}`,
   `{json: <Map>}`, top-level `List`, list with non-map entries skipped,
   malformed JSON behavior. Without this, the dedup is invisible.
2. **`kgql/repositories/models_repository_test.dart`** — move all the
   `mock.query / mutate` assertions from `providers/models_provider_test.dart`
   down here. `setModel` / `deleteModel` should be exercised directly,
   including the `delete: true` shape (currently no test covers the delete
   mutation variables). Keep `models_providers_test.dart` for *Riverpod-only*
   concerns: family caching, `Provider.overrideWithValue`, invalidation on
   `createModel`.
3. **`integration/crud_round_trip_integration_test.dart`** — create an
   Expense via `setModel`, fetch by id, mutate `cost`, delete, assert it's
   gone. This is the highest-value integration test you don't have today —
   it's the only one that exercises the seed DB end-to-end through the new
   repository functions.
4. **`kgql/documents/kgql_documents_shape_test.dart`** — call `gql(...)` on
   every exported document and assert presence of the expected variables
   (`$input`, `$filter`, `$struct`, `$userIdParam`). Cheap; catches typos
   that would otherwise hit runtime.
5. **`auth/backend_ping_test.dart`** — inject a fake `http.Client` (or pass a
   sentinel function the way `AuthController(skipBackendPing: …)` does) and
   verify success / 4xx / timeout / network-down classification. Today
   `skipBackendPing: true` means this code is never tested.
6. **`core/client/graphql_client_test.dart`** — `createClient(url, userId)`
   should be testable by composing a `Link` and round-tripping a fake
   request to inspect headers, including CF headers when the URL is
   `*.supacharger.ai`.
7. **`kgql/repositories/model_types_repository_test.dart`** — currently
   `model_types_provider_test.dart` covers shape; mirror it at the
   repository layer (no Riverpod) and trim the provider test to wiring only.
8. **`transcript/transcript_repository_test.dart`** — add mocked-client tests
   for `getTranscript`, `addMessage`, and the subscription document parser.
   Today only the parsing helper and one negative path are covered.
9. **Assertions of unwrapped result from `setKgqlModels`** in
   `models_repository_test.dart` — `setModel` returns an id parsed from
   `{json: "{…}"}`; today's PM7.5 covers happy-path. Add: (a) numeric `id`,
   (b) string `id`, (c) `id` field missing → throws / returns null per
   contract.

## Principles to enforce

- **Mirror `lib/` exactly.** Finding the test for
  `kgql/repositories/models_repository.dart` should mean opening
  `test/kgql/repositories/models_repository_test.dart`. Anything else is a
  bug.
- **Test at the lowest layer with logic.** Repositories are the new pure-Dart
  unit; providers should be tiny enough that their tests only verify wiring
  (override composition, family keying, invalidation). Today the line is
  blurred.
- **One source file → one test file**, named `<source_filename>_test.dart`.
  The few existing exceptions (`model_tags_test.dart`,
  `model_tags_edge_test.dart`) are legitimate when a single source has many
  distinct surfaces; otherwise consolidate.
- **Integration tests are for things only the live server can answer**:
  schema parity (already there), CRUD round trips (missing), subscription
  delivery (missing). Anything that can be answered with a mocked
  `GraphQLClient` does *not* belong there.
- **Shared mocking goes in `test/_support/`.** Today every provider test
  re-implements `_MockGql`, `registerFallbackValue`, and `_ok(...)` — three
  copies that drift.
- **No test imports `package:nx_db/src/...`.** Everything goes through
  `package:nx_db/nx_db.dart`. The currently-broken stale imports are exactly
  the failure mode this prevents — if the public surface changes, tests
  break in one obvious place.

## Suggested execution order

1. **Unblock compilation**: fix the four files that still import
   `src/data_providers/...` and `src/models/requests/...` so the suite at
   least runs against the new lib. (One commit, no behavior change.)
2. **Move `aggregate_provider_test.dart` →
   `kgql/repositories/aggregate_repository_test.dart`** (rename matches
   reality — it never tested a provider).
3. **Add `core/json/payload_unwrap_test.dart` and
   `core/json/json_coercion_test.dart`**, promoting the relevant helpers to
   public if they aren't already. Lowest-risk, highest-value gain.
4. **Add `kgql/documents/kgql_documents_shape_test.dart`** — pure smoke,
   catches typos for free.
5. **Split provider tests into repository + provider pairs** for `models`
   and `model_types`. Move all GraphQL-shape assertions down to the
   repository tests; keep only Riverpod wiring assertions at the provider
   level.
6. **Add `auth/backend_ping_test.dart`** with an injected HTTP client.
7. **Add `integration/crud_round_trip_integration_test.dart`** — write
   coverage you currently lack against the live seed DB.
8. **Restructure folders to mirror `lib/src/`** (`test/core/`, `test/auth/`,
   `test/kgql/{documents,models,requests,repositories,providers}/`,
   `test/transcript/`, `test/widget/`, `test/integration/`) and update
   `dart_test.yaml` tags.

After this, the heuristic *"every file in `lib/src/` has a sibling in
`test/`, and every layer is testable in isolation"* holds, and the few
integration tests verify the seams that mocked tests can't.
