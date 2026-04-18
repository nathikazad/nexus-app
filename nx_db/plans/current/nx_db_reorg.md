# `nx_db` reorganization plan

Make the package self-describing: a new reader should know what each top-level
folder is responsible for from the name alone, and should be able to find
"where is the read for X / where is the write for X" without grepping.

## Why this is needed

Today's structure has a few problems that all stem from the same root cause —
**folder names describe Dart class shapes ("models", "providers") instead of
concepts ("auth", "kgql", "transcript")**.

Concrete examples in the current layout:

- `src/db.dart` is just the GraphQL client factory.
- `src/auth.dart` mixes `User`, `AuthController`, and four sibling providers
  (`userIdProvider`, `endpointProvider`, `appStatusProvider`, …).
- `src/cf_access.dart`, `src/graphql_http_config.dart`, `src/backend_presets.dart`,
  `src/backend_ping.dart` all sit at the top level with no grouping; you can't
  tell from the names which are "config", which are "networking", which are
  "auth".
- `src/login_page.dart` is a Flutter UI page inside a "db" package — surprising
  and forces every consumer to depend on Flutter Material.
- `src/models/Model.dart` and `ModelType.dart` use **PascalCase filenames**,
  breaking Dart convention.
- `src/models/requests/` is nested under `models/`, implying a parent/child
  relationship that doesn't exist (DTOs and entities are different things).
- `src/data_providers/kgql_fetch.dart` contains plain functions and GraphQL
  doc strings — not a "provider".
- `src/data_providers/kgql_providers.dart` is two Riverpod families — vague
  name ("providers of providers"?).
- `src/data_providers/models_provider.dart` is **read + write + the
  `setKgqlModels` mutation document** in one file. The mutation is unrelated
  to the file name.
- `src/data_providers/aggregate_provider.dart` contains no Riverpod provider
  at all — just a plain function.
- `src/data_providers/transcript_provider.dart` is a grab bag: provider +
  parser + subscription + mutations + an embedded `Transcript` type.
- The same `if (raw is String) json.decode(raw)` payload-unwrapping dance is
  duplicated in `kgql_fetch.dart`, `model_types_provider.dart`,
  `transcript_provider.dart`, and `aggregate_provider.dart`.

## Target layout

```
nx_db/
  lib/
    nx_db.dart                          # public exports only (curated)

    src/
      core/                             # cross-cutting infrastructure
        config/
          backend_presets.dart
          cf_access.dart
          graphql_http_config.dart
        client/
          graphql_client.dart           # was db.dart (createClient)
          graphql_client_provider.dart  # the Riverpod provider
        json/
          json_coercion.dart            # _modelJsonInt, _parseOptionalStringField
          payload_unwrap.dart           # one place that handles String|Map|null

      auth/
        user.dart                       # the User class only
        auth_controller.dart            # AsyncNotifier
        auth_providers.dart             # userIdProvider, endpointProvider, appStatusProvider
        backend_ping.dart
        # NOTE: login_page.dart moves OUT (see "What does NOT belong" below)

      kgql/                             # generic KGQL primitives (the "ORM")
        documents/                      # one file per GraphQL operation
          get_kgql_models.graphql.dart
          set_kgql_models.graphql.dart
          get_kgql_model_type.graphql.dart
          set_kgql_model_type.graphql.dart
          get_kgql_aggregate.graphql.dart

        models/                         # raw KGQL entity types
          model.dart                    # was Model.dart (snake_case)
          model_type.dart
          attribute.dart                # ModelAttribute, AttributeDefinition
          relation.dart                 # Relation, RelationshipType
          tag_node.dart
          tag_system.dart

        requests/                       # write DTOs (sibling of models/, not child)
          set_model_request.dart
          set_model_type_request.dart

        repositories/                   # plain Dart functions, take a GraphQLClient
          models_repository.dart        # fetchKgqlModels, fetchKgqlModelById, setModel, deleteModel
          model_types_repository.dart   # fetchKgqlModelTypeByName, listAll, setModelType
          aggregate_repository.dart     # getKgqlAggregate

        providers/                      # thin Riverpod wrappers over repositories
          models_providers.dart         # modelsByTypeProvider, modelByIdProvider
          model_types_providers.dart    # modelTypeByNameProvider, allModelTypesProvider
          relation_picker_providers.dart

      transcript/                       # feature module, self-contained
        transcript.dart                 # Transcript + TranscriptMessage types
        transcript_repository.dart      # query/mutation docs + plain functions
        transcript_providers.dart       # FutureProvider, StreamProvider
```

## Why this is easier to read

- **Top-level folders describe intent.** `core/` (plumbing), `auth/` (who you
  are), `kgql/` (generic ORM), `transcript/` (a feature). A new reader
  immediately knows where to look.
- **Inside `kgql/` the layering is consistent**: `documents/` → `models/` and
  `requests/` → `repositories/` → `providers/`. You can read the stack from
  the bottom up.
- **One thing per file.** `Model.fromJson` is ~200 lines; the JSON coercion
  helpers (`_modelJsonInt`, `_parseOptionalStringField`) move to
  `core/json/json_coercion.dart` and become testable on their own.
- **Read and write live together.** `models_repository.dart` exposes
  `fetchKgqlModels`, `fetchKgqlModelById`, `setModel`, `deleteModel`. Today
  these are split between `kgql_fetch.dart` (queries) and `models_provider.dart`
  (mutations).
- **Riverpod is a thin layer.** Repositories are pure `Future<T>` functions
  taking a `GraphQLClient`. Providers wrap them. Multiple providers
  (paginated, single, picker, …) can wrap the same repository function
  without duplicating GraphQL plumbing.
- **Filenames follow Dart style.** `model.dart`, not `Model.dart`.
- **`requests/` is a sibling of `models/`**, not a child. They're different
  lifecycle objects: one is what you receive, one is what you send.
- **Feature code (`transcript/`) is self-contained.** Easy to delete or
  extract into its own package later. Same shape for any future feature
  (e.g. `notifications/`, `scheduler/`).
- **`nx_db.dart` becomes a curated public surface** — re-export only what apps
  need (`Model`, `ModelType`, `SetModelRequest`, providers, the auth bits)
  and keep `documents/`, `repositories/`, and JSON helpers internal.

## What does NOT belong in `nx_db`

These exist today but should leave the package:

- **`src/login_page.dart`** — a Flutter UI page in a "db" package forces
  every consumer to depend on Flutter Material. Move to the app, or to a
  small `nx_auth_ui` package. The auth controller/state stays in `nx_db/auth/`.

## Conventions to enforce

- **`snake_case` filenames** (Dart convention).
- **One GraphQL document per file**, lives only in `kgql/documents/`. No
  hand-written `query GetX { … }` strings scattered across providers.
- **Repositories are pure `Future`-returning functions** that take a
  `GraphQLClient`. They never read Riverpod; that's the providers' job.
- **Providers are thin wrappers** that read `graphqlClientProvider` and call
  one repository function. If a provider has 50 lines of logic, that logic
  belongs in the repository.
- **All payload unwrapping (`String | Map | { json: … }`) goes through one
  helper** in `core/json/payload_unwrap.dart`. No more per-file duplicates.
- **Nothing under `core/`, `kgql/`, or `auth/` may import a feature folder.**
  Features can import the lower layers, not the other way around.

## Mapping from today → target

| Today                                                  | Target                                                |
|--------------------------------------------------------|-------------------------------------------------------|
| `src/db.dart`                                          | `core/client/graphql_client.dart` + `…_provider.dart` |
| `src/auth.dart` (User)                                 | `auth/user.dart`                                      |
| `src/auth.dart` (AuthController)                       | `auth/auth_controller.dart`                           |
| `src/auth.dart` (userIdProvider, endpointProvider, …)  | `auth/auth_providers.dart`                            |
| `src/backend_ping.dart`                                | `auth/backend_ping.dart`                              |
| `src/backend_presets.dart`                             | `core/config/backend_presets.dart`                    |
| `src/cf_access.dart`                                   | `core/config/cf_access.dart`                          |
| `src/graphql_http_config.dart`                         | `core/config/graphql_http_config.dart`                |
| `src/login_page.dart`                                  | **out of `nx_db`** (app or `nx_auth_ui`)              |
| `src/models/Model.dart`                                | `kgql/models/model.dart`                              |
| `src/models/ModelType.dart`                            | `kgql/models/model_type.dart`                         |
| `src/models/TagNode.dart`, `TagSystem.dart`            | `kgql/models/tag_node.dart`, `tag_system.dart`        |
| `src/models/TranscriptMessage.dart`                    | `transcript/transcript.dart`                          |
| `src/models/requests/SetModelRequest.dart`             | `kgql/requests/set_model_request.dart`                |
| `src/models/requests/SetModelTypeRequest.dart`         | `kgql/requests/set_model_type_request.dart`           |
| `src/data_providers/kgql_fetch.dart` (queries)         | `kgql/repositories/models_repository.dart` + `model_types_repository.dart` |
| `src/data_providers/kgql_fetch.dart` (doc strings)     | `kgql/documents/*.graphql.dart`                       |
| `src/data_providers/models_provider.dart` (queries)    | `kgql/repositories/models_repository.dart`            |
| `src/data_providers/models_provider.dart` (mutations)  | `kgql/repositories/models_repository.dart`            |
| `src/data_providers/models_provider.dart` (Riverpod)   | `kgql/providers/models_providers.dart`                |
| `src/data_providers/model_types_provider.dart`         | split → `kgql/documents/`, `kgql/repositories/model_types_repository.dart`, `kgql/providers/model_types_providers.dart` |
| `src/data_providers/aggregate_provider.dart`           | `kgql/repositories/aggregate_repository.dart` (it's not actually a provider) |
| `src/data_providers/kgql_providers.dart`               | `kgql/providers/relation_picker_providers.dart` (rename to its actual purpose) |
| `src/data_providers/transcript_provider.dart`          | split into `transcript/transcript.dart` + `transcript_repository.dart` + `transcript_providers.dart` |

## Incremental migration order (highest readability per minute)

If a single big-bang rename is too risky, this order keeps `nx_db.dart`'s
public exports stable while improving navigability:

1. Rename `Model.dart` → `model.dart`, `ModelType.dart` → `model_type.dart`,
   etc. (snake_case). Update imports.
2. Move `models/requests/` → `kgql/requests/` (sibling of `kgql/models/`).
3. Pull `login_page.dart` out of the package.
4. Split `data_providers/` into `kgql/repositories/` (plain functions) and
   `kgql/providers/` (Riverpod wrappers). Move mutation docs into
   `kgql/documents/`.
5. Extract the duplicated JSON-payload-unwrap helper into
   `core/json/payload_unwrap.dart`.
6. Move config-y singletons (`backend_presets`, `cf_access`,
   `graphql_http_config`) into `core/config/`.
7. Split `auth.dart` and move `backend_ping.dart` into `auth/`.
8. Promote `transcript_provider.dart` into a self-contained `transcript/`
   feature folder.

After each step, `nx_db.dart` still re-exports the same public symbols, so
downstream apps don't break.
