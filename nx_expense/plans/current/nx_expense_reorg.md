# `nx_expense` reorganization plan

Make `nx_expense` look like `nx_time`. Same four layers, same naming, same
test layout. See [`mobile/nx_time/docs/arch.md`](../../../nx_time/docs/arch.md)
and [`nx_time_reorg.md`](../../../nx_time/plans/current_plan/nx_time_reorg.md)
for the prototype.

## Layer rules (verbatim from `nx_time`)

```
lib/
  core/      generic, app-agnostic, Flutter-only utilities
  domain/    PURE DART — typed entities + abstract repository interfaces
  data/      bridges domain ⇄ nx_db; KGQL + Riverpod live here and only here
  features/  screens, view-models, feature-local providers and widgets
```

| Layer | May import | Must NOT import |
|-------|------------|-----------------|
| `core/` | `flutter`, `intl`, pure Dart | `domain/`, `data/`, `features/`, any `package:nx_db/*` |
| `domain/` | pure Dart only | Flutter, Riverpod, `nx_db` |
| `data/` | `core/`, `domain/`, `flutter_riverpod`, `graphql_flutter`, `package:nx_db/{auth,kgql,riverpod}.dart` | `features/` |
| `features/` | below + `package:nx_db/auth.dart` ONLY | `package:nx_db/{nx_db,kgql,riverpod,internal}.dart`, `package:nx_db/src/...`, `graphql_flutter` |

Two layering tests in `test/layering/` enforce the bottom two rows.

## Target `lib/` blueprint

```
nx_expense/
  lib/
    main.dart                       # ProviderScope + runApp
    app.dart                        # MaterialApp.router + theme
    router.dart                     # GoRouter; redirect on authProvider

    core/
      theme/
        app_theme.dart              # was lib/app_theme.dart
      layout/
        layout.dart                 # was lib/layout.dart
      formatting/
        format.dart                 # was lib/util/format.dart (money, dates)
        teller_display.dart         # was lib/util/teller_display.dart
      widgets/
        stat_card.dart              # truly generic, used by 2+ features

    domain/                         # PURE DART
      expense/
        expense.dart
        expense_repository.dart     # list / getById / create / update / delete
        expense_filter.dart         # ExpenseFilter, ExpenseSortMode (no Flutter)
      transfer/
        transfer.dart
        transfer_repository.dart
      teller/
        teller_transaction.dart     # was TellerTransactionRow + LinkedTellerModel
        teller_link.dart            # was ExpenseTellerLink
      tag/
        tag_filter.dart             # tag-filter value types if shared (optional)

    data/                           # KGQL + Riverpod ALLOWED HERE
      providers.dart                # repo providers, schema providers,
                                    # authenticatedUserProvider — only file that
                                    # composes Ref → repositories
      expense/
        expense_attr_keys.dart      # 'date', 'ignore', amount key, …
        expense_mapper.dart         # Model ⇄ Expense, Expense → SetModelRequest
        kgql_expense_repository.dart  # implements ExpenseRepository (Ref-free)
        expense_schema_provider.dart  # cached ModelType for "Expense"
        expense_struct.dart         # buildExpenseStruct(schema)
      transfer/
        transfer_attr_keys.dart
        transfer_mapper.dart
        kgql_transfer_repository.dart
        transfer_schema_provider.dart
        transfer_struct.dart
      teller/
        teller_timeline_api.dart    # GraphQL doc + parse for timeline rows
        expense_timeline_api.dart   # link mutations + queries
        teller_sync_api.dart        # MCP HTTP `/teller/sync`
        teller_mapper.dart          # raw timeline → domain TellerTransaction
      images/
        expense_image_upload_api.dart  # MCP HTTP `/snapshots`
      aggregates/
        expense_aggregate_api.dart  # spend-by-day, by-tag, by-relation
      schema/
        kgql_schema_helpers.dart    # primaryNumberAttributeKey, chart parsers

    features/                       # SCREENS + view-models
      auth/
        expense_login_page.dart     # was screens/auth/expense_login_screen.dart
      shell/
        expense_app_end_drawer.dart # right-side menu (Tags / Teller / Logout)
      expense/
        expense_list_page.dart
        expense_list_view_model.dart   # filter + sort + search + selection state
        expense_list_filter_sheet.dart
        expense_list_sort_sheet.dart
        expense_list_bulk_actions.dart
        expense_detail_page.dart
        expense_detail_view_model.dart
        expense_form_page.dart      # merge of expense_form_screen + add_expense_screen
        expense_form_view_model.dart
        expense_dashboard_page.dart
        expense_dashboard_view_model.dart
        scoped_expense_list.dart    # ProviderScope helper for deep-linked lists
        widgets/
          expense_card.dart
          expense_date_range_bar.dart
          expense_bills_section.dart
          expense_teller_links_section.dart
          model_attribute_form_field.dart
          date_attribute_picker_field.dart
          relation_picker.dart
          tag_picker.dart
          tag_tree_tile.dart
          tag_chip.dart
      transfers/
        transfers_list_page.dart
        transfer_detail_page.dart
        transfer_form_page.dart
        transfer_relation_picker_page.dart
      teller/
        teller_list_page.dart
        teller_transaction_detail_page.dart
        teller_link_picker_page.dart
        teller_expense_link_picker_page.dart
        teller_transfer_link_picker_page.dart
        teller_transfer_quick_create_page.dart
        widgets/
          teller_detail_readonly_section.dart
      tag/
        tag_systems_page.dart
        tag_system_form_page.dart
        tag_browser_page.dart
      desktop/
        desktop_shell.dart
        desktop_nav.dart            # desktop layout state providers
        panel_chrome.dart
```

## Target `test/` blueprint

Mirrors `lib/`, one test file per source file.

```
nx_expense/test/
  _support/
    pump_app.dart
    riverpod_helpers.dart
    mock_graphql_client.dart
    fake_expense_repository.dart
    fake_transfer_repository.dart
    test_expenses.dart
    integration_auth.dart           # already exists at test/support/integration_auth.dart

  core/
    formatting/{format_test.dart, teller_display_test.dart}

  domain/
    expense/{expense_test.dart, expense_filter_test.dart}
    transfer/transfer_test.dart
    teller/{teller_transaction_test.dart, teller_link_test.dart}

  data/
    providers_test.dart             # wiring (which class each provider exposes)
    expense/
      expense_attr_keys_test.dart
      expense_mapper_test.dart
      kgql_expense_repository_test.dart    # MockGraphQLClient
      expense_struct_test.dart
    transfer/...                    # same shape
    teller/
      teller_timeline_api_test.dart
      expense_timeline_api_test.dart

  features/
    expense/
      expense_list_view_model_test.dart
      expense_form_view_model_test.dart
      expense_detail_view_model_test.dart
      expense_dashboard_view_model_test.dart

  widget/
    expense_card_widget_test.dart
    expense_teller_links_section_test.dart
    teller_transaction_detail_page_test.dart

  layering/
    no_flutter_in_domain_test.dart
    no_nx_db_in_features_test.dart

  integration/
    expense_integration_test.dart
    expense_seed_schema_integration_test.dart
```

## File-by-file move map

| Today's path | New path |
|--------------|----------|
| `lib/main.dart` | `lib/main.dart` (split: `app.dart` for `MaterialApp.router`) |
| `lib/router.dart` | `lib/router.dart` |
| `lib/app_theme.dart` | `lib/core/theme/app_theme.dart` |
| `lib/layout.dart` | `lib/core/layout/layout.dart` |
| `lib/util/format.dart` | `lib/core/formatting/format.dart` |
| `lib/util/teller_display.dart` | `lib/core/formatting/teller_display.dart` |
| `lib/util/expense_schema.dart` | split: struct → `data/expense/expense_struct.dart` + `data/transfer/transfer_struct.dart`; `Model`-aware helpers → `data/schema/kgql_schema_helpers.dart`; pure value types (`ExpenseFilter`, `ExpenseSortMode`) → `domain/expense/expense_filter.dart` |
| `lib/providers/expense_providers.dart` | split: repo + schema providers → `data/providers.dart`; list filter/sort/search/selection state → `features/expense/expense_list_view_model.dart`; aggregate providers → `features/expense/expense_dashboard_view_model.dart` |
| `lib/providers/teller_providers.dart` | split: data side → `data/providers.dart`; UI side → `features/teller/teller_list_view_model.dart` |
| `lib/data/teller_timeline_api.dart` | `lib/data/teller/teller_timeline_api.dart` |
| `lib/data/expense_timeline_api.dart` | `lib/data/teller/expense_timeline_api.dart` |
| `lib/data/teller_sync_api.dart` | `lib/data/teller/teller_sync_api.dart` |
| `lib/data/expense_image_upload_api.dart` | `lib/data/images/expense_image_upload_api.dart` |
| `lib/scoped_expense_list.dart` | `lib/features/expense/scoped_expense_list.dart` |
| `lib/screens/auth/expense_login_screen.dart` | `lib/features/auth/expense_login_page.dart` |
| `lib/screens/expense/expense_list_screen.dart` | `lib/features/expense/expense_list_page.dart` |
| `lib/screens/expense/expense_detail_screen.dart` | `lib/features/expense/expense_detail_page.dart` |
| `lib/screens/expense/expense_form_screen.dart` + `add_expense_screen.dart` | merge → `lib/features/expense/expense_form_page.dart` (mode: create \| edit) |
| `lib/screens/expense/expense_dashboard_screen.dart` | `lib/features/expense/expense_dashboard_page.dart` |
| `lib/screens/expense/expense_list_{filter,sort,bulk_actions}*.dart` | `lib/features/expense/...` (same names) |
| `lib/screens/transfers/*.dart` | `lib/features/transfers/*_page.dart` |
| `lib/screens/teller/*.dart` | `lib/features/teller/*_page.dart` |
| `lib/screens/tag/*.dart` | `lib/features/tag/*_page.dart` |
| `lib/widgets/expense_card.dart` | `lib/features/expense/widgets/expense_card.dart` |
| `lib/widgets/expense_date_range_bar.dart` | `lib/features/expense/widgets/expense_date_range_bar.dart` |
| `lib/widgets/expense_bills_section.dart` | `lib/features/expense/widgets/...` |
| `lib/widgets/expense_teller_links_section.dart` | `lib/features/expense/widgets/...` |
| `lib/widgets/{model_attribute_form_field,date_attribute_picker_field}.dart` | `lib/features/expense/widgets/...` |
| `lib/widgets/{relation_picker,tag_picker,tag_tree_tile,tag_chip}.dart` | `lib/features/expense/widgets/...` |
| `lib/widgets/teller_detail_readonly_section.dart` | `lib/features/teller/widgets/...` |
| `lib/widgets/expense_app_end_drawer.dart` | `lib/features/shell/expense_app_end_drawer.dart` |
| `lib/widgets/stat_card.dart` | `lib/core/widgets/stat_card.dart` (used by dashboard + others) |
| `lib/desktop/*.dart` | `lib/features/desktop/*.dart` |

## Conventions

1. `<feature>_page.dart` + `<feature>_view_model.dart` per screen.
2. `<entity>_attr_keys.dart` is the only place attribute key strings live.
3. `<entity>_mapper.dart` is pure functions — no `Ref`, no `BuildContext`.
4. `kgql_<entity>_repository.dart` constructors take `GraphQLClient` + schema
   loaders. Riverpod resolution happens once, in `data/providers.dart`.
5. Repositories return `domain` types — never `Model` — to `features/`.
6. `features/` may import `package:nx_db/auth.dart` only (for `User`,
   `BackendPreset`, `authProvider`). No `nx_db.dart`, no `kgql.dart`, no
   `riverpod.dart`, no `nx_db/src/...`.
7. Per-entity folders under `domain/<x>/` and `data/<x>/` use the same file
   names as `nx_db/src/kgql/shared/<x>/` so promotion is `git mv`.
8. Tests mirror `lib/` paths; layering tests in `test/layering/` are
   non-negotiable.

## Migration order

1. **Create `core/`**: move `app_theme.dart`, `layout.dart`, `util/format.dart`,
   `util/teller_display.dart`. Pure rename + import update.
2. **Create `domain/expense/` and `domain/transfer/`**: define `Expense`,
   `Transfer`, abstract `*Repository`, and value types (`ExpenseFilter`,
   `ExpenseSortMode`) currently buried in `providers/`.
3. **Create `data/expense/` and `data/transfer/`**: `attr_keys`, `mapper`,
   `kgql_*_repository`, `*_schema_provider`, `*_struct`. Repositories take
   `GraphQLClient` (not `Ref`).
4. **Move data APIs**: `teller_*` and `expense_timeline_api.dart` into
   `data/teller/`; `expense_image_upload_api.dart` into `data/images/`.
5. **Add `data/providers.dart`** — the only place that builds repos from `Ref`.
6. **Split `providers/expense_providers.dart` and `providers/teller_providers.dart`**:
   data side → `data/providers.dart`; list/dashboard/teller UI state →
   `features/<area>/*_view_model.dart`.
7. **Rename `screens/` → `features/`** and merge `expense_form_screen` +
   `add_expense_screen` into one `expense_form_page.dart` with `mode`.
8. **Move widgets**: feature-local → `features/<area>/widgets/`; reused →
   `core/widgets/`.
9. **Strip KGQL from `features/`**: replace `package:nx_db/nx_db.dart` and
   `package:nx_db/src/...` with `package:nx_db/auth.dart` + domain types
   surfaced by view-models.
10. **Mirror `test/` to `lib/`** and add the two `layering/` tests from
    `nx_time`.
11. **Optional**: split `main.dart` into `main.dart` + `app.dart` for parity.

After step 11 the layout, naming, and test placement match `nx_time` 1:1, and
promoting `Expense` / `Transfer` to `nx_db/src/kgql/shared/<entity>/` later is
a `git mv` plus an import rewrite.
