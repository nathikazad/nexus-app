# `nx_expense` tests

## Layout

| Folder | Contents |
|--------|----------|
| [`support/`](support/integration_auth.dart) | Shared helpers (e.g. live GraphQL overrides for integration) |
| [`unit/`](unit/) | Pure unit tests — schema, API parsers, providers (mocked client) |
| [`widget/`](widget/) | Widget tests |
| [`integration/`](integration/) | Live GraphQL tests (`@Tags(['integration'])`, opt-in via `RUN_EXPENSE_INTEGRATION`) |

## Default (CI / offline)

Runs **unit and widget tests** only. **Integration** tests are skipped unless you opt in (they call a real GraphQL API).

```bash
cd mobile/nx_expense
flutter test
```

To run a single file:

```bash
flutter test test/unit/expense_schema_test.dart
flutter test test/unit/expense_providers_test.dart
```

## Integration tests

Shared auth for live GraphQL: [`test/support/integration_auth.dart`](support/integration_auth.dart) — user **`1`**, [`BackendPreset.laptop`](../../nx_db/lib/src/backend_presets.dart) for the user object, with **[`expenseIntegrationOverrides`](support/integration_auth.dart)** so HTTP/WebSocket/image URLs use **[`kIntegrationTestBackendUrls`](../../nx_db/lib/src/backend_presets.dart)** (`127.0.0.1`, same ports as dev). The shipped app **Laptop** preset targets **`10.0.0.90`** instead.

| File | Role |
|------|------|
| [`integration/expense_integration_test.dart`](integration/expense_integration_test.dart) | Smoke: schema loads, tag systems exist, list non-empty |
| [`integration/expense_seed_schema_integration_test.dart`](integration/expense_seed_schema_integration_test.dart) | Stricter checks vs [`seed-data.md`](../../../servers/pgdb/docs/llm-reference/seed-data.md) (Expense `cost`, Category roots, aggregates, demo row names, tag assignments) |

**Teller / expense–timeline (unit & widget, default `flutter test`)**

| File | Role |
|------|------|
| [`unit/expense_timeline_api_test.dart`](unit/expense_timeline_api_test.dart) | `parseExpenseTimelineLinks`, `toTellerTransactionRow`, `parseTellerPayloadJson` |
| [`unit/teller_timeline_api_test.dart`](unit/teller_timeline_api_test.dart) | `parseTellerTimelineResponse`, `tellerTransactionTitleLine` |
| [`unit/teller_display_test.dart`](unit/teller_display_test.dart) | `tellerDetailHeadline`, `tellerDetailDateLabel` |
| [`widget/expense_teller_links_section_test.dart`](widget/expense_teller_links_section_test.dart) | `ExpenseTellerLinksFormSection` empty state (mocked links provider) |
| [`widget/teller_transaction_detail_screen_test.dart`](widget/teller_transaction_detail_screen_test.dart) | `TellerTransactionDetailScreen` labels |

[`unit/expense_providers_test.dart`](unit/expense_providers_test.dart) includes **`expenseTimelineLinksProvider`** (mocked GraphQL) as **P7.10**.

These use **live** `getKgqlModelType` / `getKgqlModels` / aggregates via `nx_db`’s `graphqlClientProvider`.

**Requirements**

- PostGraphile / PGDB on **localhost** at the ports in [`kIntegrationTestBackendUrls`](../../nx_db/lib/src/backend_presets.dart), or set a custom URL via code/env if your setup differs.
- Sample data loaded so `Expense` model type and rows exist.

**Run**

```bash
cd mobile/nx_expense
RUN_EXPENSE_INTEGRATION=true flutter test test/integration/expense_integration_test.dart
RUN_EXPENSE_INTEGRATION=true flutter test test/integration/expense_seed_schema_integration_test.dart
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

RUN_EXPENSE_INTEGRATION=true flutter test test/integration/expense_integration_test.dart
# from mobile/nx_expense
```
