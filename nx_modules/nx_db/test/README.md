```bash
flutter test --exclude-tags=integration   # default CI / local (no live backend)
flutter test                            # same; integration groups skip unless RUN_NX_DB_INTEGRATION=true
RUN_NX_DB_INTEGRATION=true flutter test test/integration
```

`flutter test --coverage` writes `coverage/lcov.info` (use with your preferred coverage viewer).

Layout mirrors `lib/src/`:

| Folder | Contents |
|--------|----------|
| `test/_support/` | Shared mocks (`MockGraphQLClient`, `okQueryResult`) |
| `test/core/` | Config, JSON helpers, GraphQL client smoke |
| `test/auth/` | `AuthController`, prefs, `User`, backend ping |
| `test/kgql/models/`, `requests/` | KGQL entity and write-DTO tests |
| `test/kgql/helpers/` | `buildKgqlStructFromSchema`, `setKgql*`, `ModelAttrReads` |
| `test/kgql/documents/` | `gql()` parse smoke for operation strings |
| `test/kgql/repositories/` | `fetch*` / `set*` with mocked `GraphQLClient` |
| `test/kgql/providers/` | Riverpod wiring + `createModel` / `createModelType` delegates |
| `test/models/domain/{person,transcript}`, `test/models/data/{person,transcript}` | current-user `Person` / `Transcript` (mirrors `lib/`) |
| `test/integration/` | Live GraphQL (opt-in via env) |

Future promoted entities under `lib/src/kgql/shared/<entity>/` get tests at `test/kgql/shared/<entity>/` (same mirror rule).

Prefer importing the smallest public library that supplies the symbol (e.g. `package:nx_db/kgql.dart`, `package:nx_db/auth.dart`, `package:nx_db/riverpod.dart`, `package:nx_db/person.dart`, `package:nx_db/transcript.dart`); use `package:nx_db/nx_db.dart` only when several barrels are needed.

Tag reference: see `dart_test.yaml`.
