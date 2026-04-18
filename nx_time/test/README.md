# `nx_time` tests

## Layout

| Folder | Contents |
|--------|----------|
| [`support/`](support/integration_auth.dart) | Live GraphQL overrides (user `1`, localhost URLs) |
| [`unit/`](unit/) | Pure tests — KGQL struct builders (no network) |
| [`integration/`](integration/) | Opt-in live GraphQL (`RUN_NX_TIME_INTEGRATION=true`) |

## Default (CI / offline)

```bash
cd mobile/nx_time
flutter test test/unit/
```

## Integration tests

Same pattern as [`nx_expense`](../nx_expense/test/README.md): **`test/support/integration_auth.dart`** applies **`kIntegrationTestBackendUrls`** (`127.0.0.1:5001/graphql`, …) while the logged-in user uses **`BackendPreset.laptop`** (same as the app’s LAN preset).

**Requirements**

- PostGraphile / PGDB on localhost (see `nx_db` [`kIntegrationTestBackendUrls`](../nx_db/lib/src/backend_presets.dart)).
- Seed data including **`seed_nx_time_calendar_demo`** (`Action` rows on the DB’s `CURRENT_DATE` when you ran load_data) for meaningful Today rows.

**Run**

```bash
cd mobile/nx_time
RUN_NX_TIME_INTEGRATION=true flutter test test/integration/time_integration_test.dart
```

Optional: `NX_DB_INTEGRATION_GRAPHQL_HTTP` / `NX_DB_INTEGRATION_USER_ID` — see [`nx_db` integration tests](../nx_db/test/integration/nx_db_integration_test.dart).

## Related

- **`model_type: Action`** in KGQL matches the abstract Action type **and all descendant instance rows** (Sleep, Meet, Goto, …).
- Today UI still uses **placeholder** bar/legend from [`today_snapshot_mapper.dart`](../lib/data/today_snapshot_mapper.dart) until collapse logic from `docs/current_plan/today_calendar_rendering.md` is implemented.
