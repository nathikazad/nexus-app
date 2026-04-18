# `nx_time` tests

## Layout (mirrors `lib/`)

| Folder | Contents |
|--------|----------|
| [`_support/`](_support/integration_auth.dart) | Live GraphQL overrides; screenshot auth + fixed [`todaySnapshotProvider`](_support/screenshot_auth.dart) |
| [`core/`](core/time/wall_clock_time_test.dart) | Core time/theme helpers |
| [`domain/`](domain/action/action_test.dart) | Pure Dart domain types |
| [`data/action/`](data/action/action_kgql_struct_test.dart) | KGQL struct builders |
| [`integration/`](integration/time_integration_test.dart) | Opt-in live GraphQL (`RUN_NX_TIME_INTEGRATION=true`) |

## Default (CI / offline)

Skips live GraphQL tests tagged `integration`:

```bash
cd mobile/nx_time
flutter test --exclude-tags=integration
```

Run everything including integration (requires backend + `RUN_NX_TIME_INTEGRATION=true` where tests use skip):

```bash
cd mobile/nx_time
flutter test
```

## Integration tests

Same pattern as [`nx_expense`](../nx_expense/test/README.md): **`test/_support/integration_auth.dart`** applies **`kIntegrationTestBackendUrls`** while the logged-in user uses **`BackendPreset.laptop`**.

**Requirements**

- PostGraphile / PGDB on localhost (see `nx_db` `kIntegrationTestBackendUrls`).
- Seed data including **`seed_nx_time_calendar_demo`** for meaningful Today rows.

**Run**

```bash
cd mobile/nx_time
RUN_NX_TIME_INTEGRATION=true flutter test test/integration/
```

## Simulator screenshots

`tests/screenshot_test.dart` (note the **`s`**) uses `flutter drive` — see comments in that file.
