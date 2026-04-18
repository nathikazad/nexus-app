Solid organization, **one big coverage hole**, and a couple of staleness items. Here's the breakdown.

## Organization — strong

The structure is the part that's actively easy to navigate:

```
test/
  _support/             # shared mocks (MockGraphQLClient, okQueryResult, fallbacks)
  core/
    client/             # GraphQL client smoke
    json/               # payload_unwrap, json_coercion
  auth/                 # AuthController, User, prefs
  kgql/
    models/             # Model, ModelType, tags
    requests/           # SetModelRequest, SetModelTypeRequest, set_tag_requests
    documents/          # gql() parse smoke for all 9 ops
    repositories/       # mocked GraphQLClient
    providers/          # Riverpod wiring
  transcript/           # types + repository
  integration/          # env-gated live GraphQL
```

What works well:

- **test/ mirrors lib/src/ 1:1.** A new dev adding `lib/src/kgql/repositories/foo_repository.dart` knows the test goes at `test/kgql/repositories/foo_repository_test.dart`. Zero ambiguity.
- **`_support/` for shared helpers.** `mock_graphql_client.dart` (lines 1–17) is small and reusable; both repository and provider tests use it.
- **Tags in `dart_test.yaml`** are documented (`unit`, `repository`, `provider`, `auth`, `widget`, `integration`) so you can run focused subsets, e.g. `flutter test test/kgql/repositories --tags=repository`.
- **Integration tests are env-gated** (`RUN_NX_DB_INTEGRATION=true`) and skip cleanly otherwise — local CI doesn't accidentally hit a backend.
- **Test IDs** like `MD1.1`, `CR11.5`, `PM7.4`, `IN13.1` are stable references for tracking and cross-doc citation.
- **README.md** at `test/README.md` (lines 7–22) gives the folder→contents table — very fast onboarding.

## Coverage — mostly good, with a glaring gap

Walking `lib/src/` against `test/`:

| Source area | Test file(s) | Status |
|-------------|--------------|--------|
| `core/client/graphql_client*.dart` | `core/client/graphql_client_test.dart` | ✅ |
| `core/json/payload_unwrap.dart` | `core/json/payload_unwrap_test.dart` | ✅ |
| `core/json/json_coercion.dart` | `core/json/json_coercion_test.dart` | ✅ |
| `core/config/{backend_presets,cf_access,graphql_http_config}` | piggybacks in `auth/auth_core_test.dart` (CR11.1–11.4) | ⚠️ no dedicated files |
| `auth/user.dart` | `auth/user_test.dart` | ✅ |
| `auth/auth_controller.dart` + `auth_providers.dart` | `auth/auth_core_test.dart` | ✅ |
| `auth/backend_ping.dart` | — | ❌ no dedicated test |
| `kgql/models/model.dart` | `kgql/models/model_test.dart` (+ `model_tags*`) | ✅ |
| `kgql/models/model_type.dart` | `kgql/models/model_type_test.dart` (+ `model_type_tags`) | ✅ |
| `kgql/models/tag_system.dart` | `kgql/models/tag_system{_test,_tojson_test}.dart` | ✅ |
| `kgql/models/tag_node.dart` | covered transitively via tag_system | ⚠️ no dedicated file |
| `kgql/models/attribute.dart` | covered transitively via Model | ⚠️ no dedicated file |
| `kgql/models/relation.dart` | covered transitively via Model | ⚠️ no dedicated file |
| `kgql/requests/set_model_request.dart` | `kgql/requests/set_model_request_test.dart` (+ `set_tag_requests_test`) | ✅ |
| `kgql/requests/set_model_type_request.dart` | `kgql/requests/set_model_type_request_test.dart` | ✅ |
| `kgql/documents/*.graphql.dart` (×9) | `kgql/documents/kgql_documents_shape_test.dart` (one file, 9 cases) | ✅ |
| `kgql/repositories/models_repository.dart` | `kgql/repositories/models_repository_test.dart` | ✅ |
| `kgql/repositories/model_types_repository.dart` | `kgql/repositories/model_types_repository_test.dart` | ✅ |
| `kgql/repositories/aggregate_repository.dart` | `kgql/repositories/aggregate_repository_test.dart` | ✅ |
| `kgql/providers/models_providers.dart` | `kgql/providers/models_providers_test.dart` | ✅ |
| `kgql/providers/model_types_providers.dart` | `kgql/providers/model_types_providers_test.dart` | ✅ |
| `kgql/providers/relation_picker_providers.dart` | — | ❌ no test |
| **`kgql/helpers/struct_builder.dart`** | — | ❌ **no test** |
| **`kgql/helpers/set_request_helpers.dart`** | — | ❌ **no test** |
| **`kgql/helpers/attr_accessors.dart`** | — | ❌ **no test** |
| `transcript/transcript.dart` | `transcript/transcript_test.dart` | ✅ |
| `transcript/transcript_repository.dart` | `transcript/transcript_repository_test.dart` | ✅ |
| `transcript/transcript_providers.dart` | — | ❌ no dedicated test |

### The big gap: `kgql/helpers/` has zero tests

This is the highest-priority hole. The whole point of the helpers is that **every app and every promoted entity will rely on them.** If `attrDateTime`, `setKgqlCreate`, or `buildKgqlStructFromSchema` regress, every consumer breaks silently — and there's no spec to cite when an app sees unexpected behavior.

These deserve `test/kgql/helpers/`:

- **`struct_builder_test.dart`** — schema with attrs only, schema with relations, schema with both, `includeRelationsNode: false`, `includeModelTypeMeta: false`, custom `extraTopLevel`, missing/empty link strings, schema with no attributes/relations.
- **`set_request_helpers_test.dart`** — `setKgqlCreate` JSON shape, `setKgqlUpdate` with and without `modelType`, `setKgqlDelete` payload (`{id, delete: true}`), attribute list serialization.
- **`attr_accessors_test.dart`** — string/int/double/bool/DateTime read paths, missing key, `null`, empty string, type coercion (`int` from string, `double` from int, `DateTime` ISO parse vs invalid), trim behavior.

Without these, the helpers are de-facto untested even though they're the most-shared API.

### Smaller gaps

- **`relation_picker_providers.dart`** — no test. Apps use it for picker UIs (nx_time's task picker is a direct user). At least one test verifying it queries with the expected filter shape.
- **`transcript_providers.dart`** — Riverpod wiring is uncovered; only the repository tests touch transcript. Add `transcript_providers_test.dart` for the standard "container override + read" pattern.
- **`backend_ping.dart`** — no test. Easy to mock with `MockGraphQLClient` if it just queries.
- **`tag_node.dart`, `attribute.dart`, `relation.dart`** — covered transitively via `Model` and `tag_system` tests, which is fine, but if these grow standalone behavior they'll need their own files. Currently OK.
- **`core/config/`** — covered inside `auth/auth_core_test.dart` (CR11.2–11.4 test `normalizeHttpEndpointForCf`, `BackendPreset.fromKey`, `resolve`). Mixing concerns is mild — a clean split would be `test/core/config/{backend_presets_test, cf_access_test, graphql_http_config_test}.dart`. Not urgent, but improves discoverability per the "find the test for X" rule.

## Conventions — minor inconsistencies

### 1. README.md is stale

```17:19:mobile/nx_db/test/README.md
| `test/transcript/` | Transcript types + `TranscriptService` / parsers |
| `test/widget/` | `LoginPage` |
| `test/integration/` | Live GraphQL (opt-in via env) |
```

`test/widget/` doesn't exist — `LoginPage` left `nx_db` per the boundary plan, and the widget directory went with it. The README still advertises it. The `widget` tag is also still in `dart_test.yaml` (line 21–22) with no consumer.

### 2. Tests use the kitchen-sink shim, not sub-libraries

Most tests `import 'package:nx_db/nx_db.dart'`. After the boundary plan, the cleaner pattern is to import the smallest sub-library that supplies the symbol — so a test for an auth controller imports `package:nx_db/auth.dart`, a test for a KGQL helper imports `package:nx_db/kgql.dart`. This is what apps do; tests should match. The exception is `documents/*` tests, which correctly use `package:nx_db/internal.dart` (good — they're consciously reaching into the escape hatch).

It's not a layering violation (tests are explicitly allowed the shim), but it sets the wrong example for new devs writing tests. Worth a sweep.

### 3. The `widget` tag is dead

`dart_test.yaml` line 21–22 still declares it. If no widget tests exist in `nx_db`, drop the tag — keeping it suggests there's something to find.

### 4. The `provider` / `providers` duplication

```16:18:mobile/nx_db/dart_test.yaml
  provider:
    description: "Riverpod wiring around repositories"
  providers:
    description: "Deprecated alias for provider (same intent)"
```

Self-documented as deprecated. Pick one and grep-replace.

### 5. No coverage workflow documented

The README lists what to run, but not `flutter test --coverage`. If this is the canonical shared package, a one-line addition ("`flutter test --coverage` writes to `coverage/lcov.info`") is worth it — and it makes the helper-coverage gap visible automatically.

## Discoverability for new devs

This is the most important question. Here's the test against "if a dev adds a file, do they know where the test goes?":

| Adding to lib/src/... | Test goes in... | Discoverable from... |
|-----------------------|-----------------|----------------------|
| `core/json/foo.dart` | `test/core/json/foo_test.dart` | mirror rule |
| `auth/foo.dart` | `test/auth/foo_test.dart` | mirror rule |
| `kgql/models/foo.dart` | `test/kgql/models/foo_test.dart` | mirror rule |
| `kgql/repositories/foo_repository.dart` | `test/kgql/repositories/foo_repository_test.dart` | mirror rule + README table |
| `kgql/providers/foo_providers.dart` | `test/kgql/providers/foo_providers_test.dart` | mirror rule + README table |
| `kgql/helpers/foo.dart` | `test/kgql/helpers/foo_test.dart` | **mirror rule, but no precedent yet (folder doesn't exist)** |
| `kgql/shared/<entity>/...` (future) | `test/kgql/shared/<entity>/...` | **no convention yet — needs documenting** |
| `transcript/foo.dart` | `test/transcript/foo_test.dart` | mirror rule + README table |

The mirror rule plus `_support/` for shared mocks gives 80% of the answer with zero ambiguity. The two question marks are:

- **Where does the future `kgql/shared/<entity>/` test live?** Per the mirror rule, `test/kgql/shared/<entity>/` — but this should be added to the README so the first promotion isn't a debate.
- **Where do the helpers tests live?** Same answer, but the folder doesn't exist yet, so a new dev can't pattern-match.

Both fix themselves the moment you create `test/kgql/helpers/` with the missing tests.

## Net assessment

- **Organization: 9/10.** Mirror layout, tags, README table, shared `_support/`, env-gated integration. This is the model other packages should copy.
- **Coverage: 7/10.** Entities, requests, repositories, documents, providers (mostly), transcript — all covered with substantive cases. **Helpers are uncovered**, which is a real risk because they're the most-reused API.
- **Discoverability for new devs: 8/10.** Mirror rule + README + tags works. Two improvements would make it 10: (a) precedent for `kgql/helpers/` tests, (b) explicit convention for future `kgql/shared/<entity>/` tests.

### Recommended order of fixes

1. **Add `test/kgql/helpers/{struct_builder,set_request_helpers,attr_accessors}_test.dart`.** Highest ROI by far. Establishes the precedent and closes the new-API regression risk.
2. **Update `test/README.md`**: drop the `test/widget/` row; add a row for `test/kgql/helpers/`; add a sentence about the future `test/kgql/shared/<entity>/` convention so the first promotion is mechanical on the test side too.
3. **Drop the `widget` tag** and consolidate `provider`/`providers` in `dart_test.yaml`.
4. **Add tests for `relation_picker_providers`, `transcript_providers`, and `backend_ping`.** Small, mechanical.
5. **Sweep test imports** to use sub-libraries (`nx_db/auth.dart`, `nx_db/kgql.dart`, `nx_db/riverpod.dart`) so tests model the import discipline apps must follow.
6. **Optional**: split `auth/auth_core_test.dart` so `core/config/*` files get their own test files (improves "find the test for X" mapping).

Once #1 and #2 land, the test surface fully matches the source surface and the "where does this test go?" question has a one-line answer for every case.