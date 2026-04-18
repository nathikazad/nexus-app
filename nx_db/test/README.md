```bash
flutter test --exclude-tags=integration   # default CI / local (no live backend)
flutter test                            # same; integration groups skip unless RUN_NX_DB_INTEGRATION=true
RUN_NX_DB_INTEGRATION=true flutter test test/integration
```

Layout mirrors `lib/src/`:

| Folder | Contents |
|--------|----------|
| `test/_support/` | Shared mocks (`MockGraphQLClient`, `okQueryResult`) |
| `test/core/` | Config, JSON helpers, GraphQL client smoke |
| `test/auth/` | `AuthController`, prefs, `User` |
| `test/kgql/models/`, `requests/` | KGQL entity and write-DTO tests |
| `test/kgql/documents/` | `gql()` parse smoke for operation strings |
| `test/kgql/repositories/` | `fetch*` / `set*` with mocked `GraphQLClient` |
| `test/kgql/providers/` | Riverpod wiring + `createModel` / `createModelType` delegates |
| `test/transcript/` | Transcript types + `TranscriptService` / parsers |
| `test/widget/` | `LoginPage` |
| `test/integration/` | Live GraphQL (opt-in via env) |

Tag reference: see `dart_test.yaml`.
