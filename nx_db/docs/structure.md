# `nx_db` structure

## What `nx_db` is

A Flutter package that gives any Nexus app three things and only three
things:

1. **Auth** — sign in with a user id + backend preset; persist the
   session; expose the current `User` and the resolved endpoint URLs.
2. **A KGQL "ORM"** — typed `Model` / `ModelType` / `SetModelRequest`
   classes plus a small set of repository functions (`fetchKgqlModels`,
   `setKgqlModel`, …) that talk to the PGDB GraphQL backend.
3. **A few cross-app feature modules** (today: `transcript/`, `goals/`) when
   a feature is genuinely shared by ≥2 apps.

It does **not** ship UI screens, app-specific entities, or business
logic. Apps import it; it does not import them.

## Why this package exists

There are many Nexus apps (`nx_time`, `nx_expense`, future apps) and
**one** backend they all talk to: a PGDB GraphQL API addressed by a
small set of operations on a generic schema (KGQL — Knowledge Graph
Query Language: `Model`, `ModelType`, attributes, relations, tags).
Every app needs the same machinery to use it:

- A way for the user to sign in with a user id and pick which backend
  environment to hit (laptop, Pi-LAN, Pi-Tailscale, prod), then have
  that session survive an app restart.
- A `GraphQLClient` configured with the right endpoint, the right
  `x-user-id` header, and the right Cloudflare Access headers for
  remote backends.
- Typed Dart classes for the entities the API returns (`Model`,
  `ModelType`, `Relation`, `Tag…`) and the write payloads it expects
  (`SetModelRequest`, `SetModelTypeRequest`).
- A handful of operation strings (`get_kgql_models`,
  `set_kgql_models`, `get_kgql_model_type`, `get_kgql_aggregate`, …)
  and the parsing logic that turns their JSON responses into those
  typed classes.
- A way to expose all of the above to a Flutter UI in a Riverpod-shaped
  form, plus reusable picker / fetcher providers.

If each app builds those things itself, the same code is rewritten —
and re-debugged — in every app. Worse, when the GraphQL contract or the
auth model evolves, every app has to be patched in lockstep.

`nx_db` exists to **be that shared layer once, for every Nexus app**.
It owns:

- **Auth** — `User`, `AuthController`, backend presets, session
  persistence, the GraphQL warm-up ping.
- **The KGQL "ORM"** — typed reads (`Model` & friends), typed writes
  (`SetModelRequest` & friends), the operation documents, and the
  repository functions that connect the two.
- **The Riverpod surface** that wraps all of that for Flutter apps.
- **Cross-app feature modules** (today: `transcript/`) when an entire
  vertical feature is genuinely shared.

It deliberately does **not** own:

- **UI screens.** Each app builds its own login screen, its own theme,
  its own widgets — `nx_db` only exposes the data and controllers they
  need.
- **App-specific entities or business logic.** A typed `Action` or
  `Expense` lives in its app until it's needed by two apps, at which
  point it's promoted into `kgql/shared/`.
- **Anything that imports an app.** The dependency direction is one-way:
  apps import `nx_db`; `nx_db` knows nothing about them.

Holding that line — one shared layer for the things that genuinely
must be shared, zero shared code for everything else — is what every
folder, sub-library, and convention in this package is in service of.

## How `nx_db` solves it

Three structural moves:

### 1. Layered folders by concept (not by Dart shape)

```
core/         cross-cutting infrastructure (config, GraphQL client, JSON helpers)
auth/         identity / session — User, AuthController, providers, backend_ping
kgql/         the generic "ORM" over the PGDB GraphQL API
transcript/   one self-contained feature module
goals/        `app` schema goal orchestrators (week, trend, expense month)
```

A new reader opens `lib/src/` and immediately knows which folder owns
each concern. Inside `kgql/` the same idea repeats with a
**stack** that reads bottom-up:

```
kgql/
  documents/      one .dart file per GraphQL operation
  models/         what you receive (Model, ModelType, attributes, relations, tags)
  requests/       what you send (SetModelRequest, SetModelTypeRequest)
  repositories/   plain Future-returning functions over GraphQLClient
  providers/      thin Riverpod wrappers over repositories
  helpers/        struct_builder, set_request_helpers, attr_accessors
  shared/         (reserved) typed entities promoted from apps
```

Hard rules inside the `lib/`:

- `core/`, `auth/`, `kgql/` may not import `transcript/`, `goals/`, or any
  other feature module. **Features import lower layers, not the reverse.**
- Repositories take a `GraphQLClient`, never a Riverpod `Ref`.
- Providers are thin wrappers — if a provider has 50 lines of logic, the
  logic belongs in the repository.

### 2. A curated public surface — multiple sub-libraries

`nx_db` exposes its API through multiple sub-library entry points. Apps pick
the smallest one that fits.

| Import path | What it gives you | Riverpod? | Flutter? |
|-------------|-------------------|-----------|----------|
| `package:nx_db/auth.dart` | `User`, `AuthController`, `authProvider`, `userIdProvider`, `endpointProvider`, `BackendPreset`, `BackendUrls`, `pingGraphqlBackend`, HTTP config | yes (auth providers) | no |
| `package:nx_db/kgql.dart` | `Model`, `ModelType`, `SetModelRequest`, `SetModelAttribute`, repositories (`fetchKgqlModels`, `setKgqlModel`, …), helpers (`buildKgqlStructFromSchema`, `setKgqlCreate/Update/Delete`, `attrString/attrDateTime/...`), `GraphQLClient` | **no** | no |
| `package:nx_db/riverpod.dart` | `graphqlClientProvider`, `modelsByTypeProvider`, `modelTypeByNameProvider`, relation picker providers | yes | no |
| `package:nx_db/transcript.dart` | `Transcript`, `TranscriptMessage`, repository, providers | yes | no |
| `package:nx_db/goals.dart` | `fetchActionGoalsWeek` / `fetchActionGoalsTrend` / `fetchExpenseGoalsMonth`, DTOs, GraphQL operation strings | no | no |
| `package:nx_db/nx_db.dart` | Everything-shim — re-exports all of the above; prefer the focused sub-libraries | yes | no |
| `package:nx_db/internal.dart` | Raw GraphQL document strings + JSON helpers; **may break in any release** | no | no |

The split matters for two reasons:

- **Apps don't pay for what they don't use.** A non-Riverpod consumer
  imports `package:nx_db/kgql.dart` and gets pure functions over a
  `GraphQLClient`. A CLI could use it.
- **Refactoring nx_db internals stops being a breaking change.** Apps
  should not import `package:nx_db/src/...` or `package:nx_db/internal.dart`,
  so renames inside `src/` are safe.

### 3. Generic helpers + a shared-entity tier

Three helpers live in `src/kgql/helpers/` and remove per-entity
boilerplate from every app:

- **`buildKgqlStructFromSchema(ModelType)`** — walks
  `schema.attributes` + `schema.relations` and produces the `struct` map
  that `get_kgql_models` expects. Replaces ~50 lines of per-entity code.
- **`setKgqlCreate / setKgqlUpdate / setKgqlDelete`** — typed factories
  for `SetModelRequest`. App mappers only build the `attributes:` list.
- **`attrString / attrInt / attrDouble / attrBool / attrDateTime`** —
  extension methods on `Model` that replace the
  `if (raw is String) … else raw.toString()` dance with one typed call.

The **`kgql/shared/`** folder is the promotion target. When a typed
entity (e.g. `Action`) is shared by ≥2 apps, its files move from the
app's `domain/<x>/` + `data/<x>/` into `nx_db/src/kgql/shared/<x>/` and
are re-exported as `package:nx_db/<x>.dart`. The folder is empty today —
the convention exists, the first migration happens when a second app
needs it. See `plans/current/nx_db_app_boundary.md` for the full
promotion recipe.

## Folder layout in detail

```
nx_db/
  lib/
    nx_db.dart            # everything-shim; prefer the focused sub-libraries
    auth.dart             # public sub-library
    kgql.dart             # public sub-library (Riverpod-free)
    riverpod.dart         # public sub-library (opt-in Riverpod)
    transcript.dart       # public sub-library (feature module)
    goals.dart            # public sub-library (app goal orchestrators)
    internal.dart         # not part of public API; tests / advanced use only

    src/
      core/
        client/
          graphql_client.dart            # createClient(endpoint, userId)
          graphql_client_provider.dart   # graphqlClientProvider
        config/
          backend_presets.dart           # BackendPreset enum + resolve()
          cf_access.dart                 # Cloudflare Access headers
          graphql_http_config.dart       # x-user-id header injection
        json/
          payload_unwrap.dart            # one place for the String|Map|null dance
          json_coercion.dart             # asJsonInt, parseOptionalStringField, …

      auth/
        user.dart                        # the User class
        auth_controller.dart             # AsyncNotifier<User?>
        auth_providers.dart              # userIdProvider, endpointProvider, appStatusProvider, …
        backend_ping.dart                # warm-up GET to the GraphQL endpoint

      kgql/
        documents/                       # one .graphql.dart per operation
          get_kgql_models.graphql.dart
          set_kgql_models.graphql.dart
          get_kgql_model_type.graphql.dart
          get_kgql_model_type_all.graphql.dart
          set_kgql_model_type.graphql.dart
          get_kgql_aggregate.graphql.dart
          # …transcript documents live here too
        models/                          # read-side types (from API responses)
          model.dart                     # the Model class
          model_type.dart
          attribute.dart                 # ModelAttribute, AttributeDefinition
          relation.dart                  # Relation, RelationshipType
          tag_node.dart
          tag_system.dart
        requests/                        # write-side DTOs
          set_model_request.dart         # SetModelRequest, SetModelAttribute
          set_model_type_request.dart
        repositories/                    # plain Dart over GraphQLClient
          models_repository.dart         # fetchKgqlModels, fetchKgqlModelById, setKgqlModel, …
          model_types_repository.dart    # fetchKgqlModelTypeByName, listAll, setModelType
          aggregate_repository.dart      # getKgqlAggregate
        providers/                       # thin Riverpod over repositories
          models_providers.dart          # modelsByTypeProvider, modelByIdProvider
          model_types_providers.dart     # modelTypeByNameProvider, allModelTypesProvider
          relation_picker_providers.dart # picker lists
        helpers/                         # generic plumbing apps shouldn't reinvent
          struct_builder.dart
          set_request_helpers.dart
          attr_accessors.dart
        shared/                          # (reserved for promoted entities)

      transcript/                        # a feature module — self-contained
        transcript.dart                  # Transcript + TranscriptMessage types
        transcript_repository.dart       # query / mutation / subscription docs + functions
        transcript_providers.dart        # FutureProvider, StreamProvider

      goals/                             # app schema goal orchestrators
        documents/                       # get_action_goals_week / _trend / get_expense_goals_month
        models/                          # wire DTOs (week, trend, expense month, streak, …)
        goal_parsing.dart                # date / JSON unwrapping helpers
        goals_repository.dart            # fetch* over GraphQLClient
```

The layering inside `kgql/` reads bottom-up: `documents` → `models` /
`requests` → `repositories` → `providers` → `helpers`. Every step is
optional from the layer above's point of view (a repository works without
its provider; a provider works without the helpers).

## How the tests are organized

`test/` mirrors `lib/src/` exactly — same folder names, same nesting.
**One test file per source file** is the goal; tests live where the code
they cover lives.

```
nx_db/test/
  _support/
    mock_graphql_client.dart            # MockGql, fallback registration, okQueryResult helpers

  core/
    client/
      graphql_client_test.dart          # createClient: x-user-id header, CF headers
    json/
      payload_unwrap_test.dart          # null|String|Map|{json:…}|List → canonical
      json_coercion_test.dart           # int / optional-string parsing edges

  auth/
    user_test.dart                      # equality / hashCode
    auth_core_test.dart                 # AuthController happy + error paths
    backend_ping_test.dart              # pingGraphqlBackend: 200 ok + GraphQL errors

  kgql/
    documents/
      kgql_documents_shape_test.dart    # gql() parse smoke for every operation
    models/
      model_test.dart
      model_type_test.dart
      model_tags_test.dart
      model_tags_edge_test.dart
      model_type_tags_test.dart
      tag_system_test.dart
      tag_system_tojson_test.dart
    requests/
      set_model_request_test.dart       # toJson shapes, delete short-circuit
      set_model_type_request_test.dart
      set_tag_requests_test.dart
    helpers/                            # generic plumbing over Model / ModelType / SetModelRequest
      struct_builder_test.dart          # buildKgqlStructFromSchema
      set_request_helpers_test.dart     # setKgqlCreate / setKgqlUpdate / setKgqlDelete
      attr_accessors_test.dart          # ModelAttrReads.attr{String,Int,Double,Bool,DateTime}
    repositories/                       # mocked GraphQLClient — pure-Dart unit tests
      models_repository_test.dart
      model_types_repository_test.dart
      aggregate_repository_test.dart
    providers/                          # Riverpod wiring + variable-shape assertions on mocked repos
      models_providers_test.dart
      model_types_providers_test.dart
      relation_picker_providers_test.dart

  transcript/
    transcript_test.dart                # types + parsing
    transcript_repository_test.dart     # query/mutate/subscribe with mocked client
    transcript_providers_test.dart      # barrel re-export smoke

  goals/
    goals_documents_shape_test.dart
    models/
      action_goal_week_test.dart
      action_goal_trend_test.dart
      expense_goal_month_test.dart
    goals_repository_test.dart

  integration/                          # opt-in; live PGDB required
    nx_db_integration_test.dart
    seed_data_schema_integration_test.dart
```

### Tagging and selection

`dart_test.yaml` declares a small set of tags so tests can be selected by
intent:

| Tag | Meaning |
|-----|---------|
| `unit` | Pure model / request / json-coercion tests. No I/O, no Riverpod. |
| `repository` | KGQL repositories with a mocked `GraphQLClient`. |
| `provider` | Riverpod providers wrapping mocked repositories. |
| `auth` | `AuthController` + prefs (mocked `SharedPreferences`); also covers `pingGraphqlBackend`. |
| `integration` | Live GraphQL; requires `RUN_NX_DB_INTEGRATION=true`. |

### How to run

```bash
flutter test --exclude-tags=integration         # default (no live backend)
flutter test test/kgql/repositories             # by folder
flutter test --tags=repository                  # by tag
RUN_NX_DB_INTEGRATION=true flutter test test/integration
flutter test --coverage                         # writes coverage/lcov.info; open with an LCOV viewer or `genhtml coverage/lcov.info -o coverage/html`
```

### Conventions for new tests

- **Place the test next to its source.** A new file at
  `lib/src/kgql/foo/bar.dart` gets a test at `test/kgql/foo/bar_test.dart`.
- **Test the lowest layer with logic.** Repositories carry the GraphQL
  contract — test them directly with a mocked `GraphQLClient`. Providers
  get smoke / wiring tests only.
- **Documents get a `gql()` parse test** in
  `test/kgql/documents/kgql_documents_shape_test.dart`. A typo in a
  `.graphql.dart` file should fail the suite, not blow up at runtime in a
  downstream app.
- **Helpers (`buildKgqlStructFromSchema`, `attr*`, `setKgql*`) get unit
  tests** under `test/kgql/helpers/`, mirroring `lib/src/kgql/helpers/`.
  See `struct_builder_test.dart`, `set_request_helpers_test.dart`, and
  `attr_accessors_test.dart` as the precedent.
- **Integration tests are opt-in and tagged.** They never run by default
  and never block PR CI without `RUN_NX_DB_INTEGRATION=true`.

## Where to put new code

Quick decision table for contributors:

| You're adding… | Goes in… | Public surface? |
|----------------|----------|------------------|
| A new GraphQL operation string | `src/kgql/documents/<op>.graphql.dart` | no — internal; consumed by repositories |
| A new typed read field on `Model` | `src/kgql/models/model.dart` (or a sibling) | yes — via `kgql.dart` |
| A new write payload | `src/kgql/requests/<x>_request.dart` | yes — via `kgql.dart` |
| A new pure async function over `GraphQLClient` | `src/kgql/repositories/<x>_repository.dart` | yes — via `kgql.dart` |
| A new Riverpod wrapper over a repository fn | `src/kgql/providers/<x>_providers.dart` | yes — via `riverpod.dart` |
| A generic helper over `Model` / `ModelType` / `SetModelRequest` | `src/kgql/helpers/<x>.dart` | yes — via `kgql.dart` |
| A new auth-y concern | `src/auth/<x>.dart` + maybe `auth.dart` export | yes — via `auth.dart` |
| A typed entity used by ≥2 apps (promotion) | `src/kgql/shared/<x>/` + new `lib/<x>.dart` re-export | yes — via `<x>.dart` |
| A new vertical feature module | `src/<feature>/` + new `lib/<feature>.dart` re-export | yes — via `<feature>.dart` |
| Anything Flutter Material | **not in `nx_db`** — belongs in the consuming app or a UI package |

When in doubt, the rule is: **does this concept exist independently of
any one app?** If yes, it can live in `nx_db`. If no, it stays in the
app.
