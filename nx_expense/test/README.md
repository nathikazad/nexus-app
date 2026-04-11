# `nx_expense` tests

## Default (CI / offline)

Runs **unit and widget tests** only. **Integration** tests are skipped unless you opt in (they call a real GraphQL API).

```bash
cd mobile/nx_expense
flutter test
```

To run a single file:

```bash
flutter test test/expense_schema_test.dart
flutter test test/expense_providers_test.dart
```

## Integration tests

Shared auth for live GraphQL: [`test/support/integration_auth.dart`](support/integration_auth.dart) — user **`1`**, [`BackendPreset.laptop`](../../nx_db/lib/src/backend_presets.dart) for the user object, with **[`expenseIntegrationOverrides`](support/integration_auth.dart)** so HTTP/WebSocket/image URLs use **[`kIntegrationTestBackendUrls`](../../nx_db/lib/src/backend_presets.dart)** (`127.0.0.1`, same ports as dev). The shipped app **Laptop** preset targets **`10.0.0.90`** instead.

| File | Role |
|------|------|
| [`expense_integration_test.dart`](expense_integration_test.dart) | Smoke: schema loads, tag systems exist, list non-empty |
| [`expense_seed_schema_integration_test.dart`](expense_seed_schema_integration_test.dart) | Stricter checks vs [`seed-data.md`](../../../servers/pgdb/docs/llm-reference/seed-data.md) (Expense `cost`, Category roots, aggregates, demo row names, tag assignments) |

These use **live** `getKgqlModelType` / `getKgqlModels` / aggregates via `nx_db`’s `graphqlClientProvider`.

**Requirements**

- PostGraphile / PGDB on **localhost** at the ports in [`kIntegrationTestBackendUrls`](../../nx_db/lib/src/backend_presets.dart), or set a custom URL via code/env if your setup differs.
- Sample data loaded so `Expense` model type and rows exist.

**Run**

```bash
cd mobile/nx_expense
RUN_EXPENSE_INTEGRATION=true flutter test test/expense_integration_test.dart
RUN_EXPENSE_INTEGRATION=true flutter test test/expense_seed_schema_integration_test.dart
```

Or run the whole `test/` folder with integration enabled:

```bash
RUN_EXPENSE_INTEGRATION=true flutter test
```

**Tag** (optional): integration tests are tagged `integration`:

```bash
flutter test --exclude-tags=integration
RUN_EXPENSE_INTEGRATION=true flutter test --tags=integration
```

## Related: `nx_db` integration

Package **`nx_db`** uses a separate env flag for its own live tests: `RUN_NX_DB_INTEGRATION=true`. You can run both when your local DB is up:

```bash
RUN_NX_DB_INTEGRATION=true flutter test
# from mobile/nx_db

RUN_EXPENSE_INTEGRATION=true flutter test test/expense_integration_test.dart
# from mobile/nx_expense
```
