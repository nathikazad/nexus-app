# `nx_time` test suite reorganization plan

Companion to [`nx_time_reorg.md`](./nx_time_reorg.md). The `lib/` reorg
introduces a strict **core / domain / data / features** layering. The test
suite today does not match any of that — it has one unit test, one
integration suite, and a `tests/` folder for screenshots — so almost
nothing of the current test code carries over unchanged. This document
records where coverage stands today and how to restructure the suite so
each layer is testable in isolation, with a few integration tests to
verify the seams.

## Where the suite stands today

### What exists

| Path | Purpose |
|------|---------|
| `test/unit/time_kgql_schema_test.dart` | One file. Asserts `buildActionActivityStruct(ModelType)` includes core fields, attributes, and nested `Place` relation. |
| `test/integration/time_integration_test.dart` | Live GraphQL: schema loads, today snapshot, day-window filter, Meet by id, Sleep inheritance, Task picker. Skips unless `RUN_NX_TIME_INTEGRATION=true`. |
| `test/support/integration_auth.dart` | `TestAuthController` + `timeIntegrationOverrides` for live tests. |
| `test/support/screenshot_auth.dart` | `ScreenshotAuthController` + `screenshotAuthOverrides` for golden capture. |
| `test/support/screenshot_today_repository.dart` | Fixed `TodaySnapshot` (with deprecated `actionModels: [null,…]`) for stable screenshots. |
| `tests/screenshot_test.dart` (note the **`s`**) | iOS simulator `flutter drive` harness. Pumps each tab + push, captures PNGs to `tests/screenshots/`. |
| `test/README.md` | Run instructions. |

### Coverage by surface area (target `lib/` layout vs existing tests)

| New `lib/` location | Test today | Coverage |
|---|---|---|
| `core/time/wall_clock_time.dart` | none | **gap** |
| `core/time/time_window.dart` | none | **gap** (new file) |
| `core/theme/action_color_palette.dart` | none | **gap** (color stability matters) |
| `core/theme/app_theme.dart` | none | smoke only |
| `core/formatting/time_format.dart` | none | **gap** ("h:mm AM split", "1h 25m") |
| `core/formatting/date_label.dart` | indirectly via integration `'Today — Sat, Apr 18'` | **gap** (no isolated test) |
| `core/layout/layout.dart` | none | n/a (constants) |
| `core/widgets/*` | none | **gap** |
| `domain/action/action.dart` | none | **gap** |
| `domain/action/action_category.dart` | none | **gap** |
| `domain/action/action_repository.dart` (interface) | n/a (interface) | n/a |
| `domain/tasks/*`, `goals/*`, `schema/*` | none | **gap** |
| `data/action/action_kgql_struct.dart` | `unit/time_kgql_schema_test.dart` | adequate, **wrong path** |
| `data/action/action_attr_keys.dart` | none (constants) | smoke worth it |
| `data/action/action_mapper.dart` | none — biggest **gap**: no test of `Model -> Action` and `Action -> SetModelRequest` |
| `data/action/kgql_action_repository.dart` | only via integration | **gap** at unit level (mocked client) |
| `data/tasks/kgql_task_repository.dart` | none | **gap** |
| `data/schema/kgql_action_schema_repository.dart` | only via integration | **gap** |
| `data/providers.dart` | none | smoke only |
| `features/today/today_view_model.dart` | none | **gap** — biggest UI-layer gap; the day fraction / segment math is non-trivial |
| `features/today/today_page.dart` | screenshots only | **gap** (interaction: tap row → push detail) |
| `features/today/widgets/*` | none | **gap** (golden where stable) |
| `features/action_detail/action_detail_view_model.dart` | none | **gap** |
| `features/action_detail/action_detail_page.dart` | none | **gap** (Edit button enable/disable, Notes visibility) |
| `features/action_edit/action_edit_view_model.dart` | none | **gap** — form validation + create vs edit branching |
| `features/action_edit/action_edit_page.dart` | none | **gap** (pickers integrate, save calls repo) |
| `features/action_edit/widgets/action_*_picker.dart` | none | **gap** |
| `features/calendar/*` | none | **gap** |
| `features/tasks/*` | none | **gap** |
| `features/shell/app_shell.dart` | screenshots | **gap** (tab switching, pushed-route navigation) |
| `features/auth/time_login_screen.dart` | none | **gap** |
| `features/settings/*` | none | **gap** |
| Live integration | `test/integration/time_integration_test.dart` (8 tests) | strong for read paths; **no write/CRUD test** |

### Things that will break in-place when `nx_time_reorg.md` lands

- `test/unit/time_kgql_schema_test.dart` imports `nx_time/data/time_kgql_schema.dart` → moves to `data/action/action_kgql_struct.dart`.
- `test/integration/time_integration_test.dart` imports `nx_time/data/today_repository.dart` and `data/time_kgql_schema.dart` → both move; `actionSchemaProvider`, `todayRepositoryProvider`, `kActionModelTypeName` will live in `data/providers.dart` / `data/schema/`.
- `test/support/screenshot_today_repository.dart` builds a `TodaySnapshot` with `actionModels: [null,…]` — that field is being **removed** in step 5 of the reorg. The stub becomes a fake `ActionRepository` returning a fixed `List<Action>` instead.
- `test/support/screenshot_auth.dart` overrides `todayRepositoryProvider` → must override `actionRepositoryProvider` after step 5.

### Why the structure itself is wrong (not just stale paths)

1. **One unit file** does not match a five-layer codebase. There is no place to add a domain test, a view-model test, or a widget test.
2. **`data/` mapping logic has zero unit coverage.** `Model -> Action` and `Action -> SetModelRequest` are the most error-prone code in the app and only get exercised end-to-end by the live integration tests.
3. **View-model construction (`today_snapshot_mapper`, `activityDetailArgsForModel`) has zero unit coverage.** All the date/time formatting, color picking, and segment-fraction math is exercised only when you run the app.
4. **Screenshot tests live in a sibling `tests/` folder**, hidden from `flutter test`. `tests/screenshot_test.dart` runs only via `flutter drive` on a simulator. There is no Flutter-test-runner widget test (which would catch ~90% of regressions in seconds, on every push) for any page.
5. **Integration tests cover read paths only.** Create / edit / delete an action through the repository is the workflow most likely to regress when the data layer is rewritten — and there is no test for it.
6. **No layering enforcement.** Nothing prevents a feature widget from importing `package:nx_db/...` once the file naming convention shifts. The reorg explicitly requires this rule (rule #2 in `nx_time_reorg.md`); the test suite is the obvious place to assert it.

## Target layout — mirror `lib/` exactly

Every layer gets its own folder. One test file per source file. Domain
tests are pure Dart (fastest, no Flutter binding); data tests use a
mocked GraphQL client; feature tests split into pure-Dart view-model
tests + Flutter widget/golden tests + a few integration tests.

```
test/
  _support/
    fake_action_repository.dart          # in-memory ActionRepository (domain)
    fake_action_schema_repository.dart   # canned ModelType for schema-driven UI
    mock_graphql_client.dart             # re-export of nx_db's helpers
    riverpod_helpers.dart                # makeContainer({overrides}) helper
    pump_app.dart                        # tester.pumpAppWith({overrides, page})
    test_actions.dart                    # canned Action / ActionCategory factories
    integration_auth.dart                # current file, unchanged
    screenshot_auth.dart                 # current, after migration to fake repo
    layering_test_helpers.dart           # AST-based import scanner (see below)

  core/
    time/
      wall_clock_time_test.dart          # local-wall-clock semantics, DST edge
      time_window_test.dart              # overlap, contains, day-bounded windows
    theme/
      action_color_palette_test.dart     # stable HSL by modelTypeId; pill style derivation
    formatting/
      time_format_test.dart              # 'h:mm AM' split, '1h 25m', '00:32:14'
      date_label_test.dart               # 'Today — Sat, Apr 18'
    widgets/
      nx_app_menu_button_test.dart       # tap → callback, golden in default state
      nx_tab_header_test.dart
      task_status_segmented_test.dart
      task_row_tile_test.dart            # important shared widget; golden + tap

  domain/
    action/
      action_test.dart                   # constructors, equality, copyWith
      action_category_test.dart
    tasks/
      task_test.dart
    goals/
      goal_test.dart
    schema/
      action_schema_test.dart

  data/
    action/
      action_kgql_struct_test.dart       # was unit/time_kgql_schema_test.dart
      action_attr_keys_test.dart         # constants exist, no typos
      action_mapper_test.dart            # Model -> Action; Action -> SetModelRequest; round-trip
      kgql_action_repository_test.dart   # mocked GraphQLClient: list/get/create/update/delete
    tasks/
      kgql_task_repository_test.dart
    schema/
      kgql_action_schema_repository_test.dart
    providers_test.dart                  # smoke: provider tree composes; overrides apply

  features/
    today/
      today_view_model_test.dart         # pure: domain Action[] -> view-model strings/colors/fractions
      today_page_test.dart               # widget: pump page with fakeActionRepository, tap row → navigates
      widgets/
        time_map_bar_test.dart           # golden(s) — stable across pure data
        time_map_segment_test.dart
        activity_row_test.dart           # golden + tap callback
        category_legend_test.dart
    action_detail/
      action_detail_view_model_test.dart # pure: Action -> view-model (date first, pill, notes-visible)
      action_detail_page_test.dart       # widget: Edit disabled when source missing; Notes shown
    action_edit/
      action_edit_view_model_test.dart   # pure: validation, create vs edit branch, save delegates
      action_edit_page_test.dart         # widget: picker open, save → repo.upsert called once
      widgets/
        action_category_picker_test.dart
        action_datetime_picker_test.dart
    calendar/
      calendar_view_model_test.dart
      calendar_page_test.dart
    tasks/
      tasks_page_test.dart               # at least one test per page; expand as features harden
      task_detail_page_test.dart
      task_create_page_test.dart
      task_edit_page_test.dart
      task_picker_page_test.dart
      projects_browse_page_test.dart
    shell/
      app_shell_test.dart                # tab switching, push detail with model present
    auth/
      time_login_screen_test.dart
    settings/
      action_colors_page_test.dart

  layering/
    no_nx_db_in_features_test.dart       # AST scan of lib/features/**
    no_flutter_in_domain_test.dart       # AST scan of lib/domain/**

  golden/                                # generated PNGs live here, checked in
    today_page/
    action_detail_page/
    action_edit_page/

  integration/                           # opt-in (RUN_NX_TIME_INTEGRATION=true)
    time_integration_test.dart           # current; rename of paths only
    crud_round_trip_integration_test.dart   # NEW — create→get→update→delete an Action
```

### `tests/` (separate folder, simulator screenshots)

`tests/screenshot_test.dart` keeps doing what it does (full-app capture
on a real iOS simulator via `flutter drive`). Conceptually it is a
**third tier** of testing — visual diffs against design refs. Don't
fold it into `test/`; the runners are different.

```
tests/
  screenshot_test.dart            # unchanged; uses test/_support/screenshot_auth.dart
  driver.dart                     # unchanged
  ref_capture/                    # design refs (HTML / PNG)
  screenshots/                    # captured PNGs (gitignored)
  compare_*.py                    # pixel diff scripts
```

### Updated `dart_test.yaml`

```yaml
tags:
  domain:      { description: "Pure Dart domain entity/repo-interface tests" }
  data:        { description: "Data-layer mappers & repositories (mocked GraphQLClient)" }
  view_model:  { description: "Pure feature view-model tests" }
  widget:      { description: "Flutter widget / page tests with fake repositories" }
  golden:      { description: "Golden-image widget tests" }
  layering:    { description: "Architectural import-rule tests" }
  integration: { description: "Live GraphQL — also requires RUN_NX_TIME_INTEGRATION=true" }
```

The default `flutter test --exclude-tags=integration` runs everything
that doesn't need the backend — the same ergonomics `nx_db` now has.

## Coverage gaps that need new tests (priority order)

1. **`data/action/action_mapper_test.dart`** — the biggest mapping risk
   in the app (KGQL `Model` ↔ domain `Action`). Cover: read-path with
   typed attributes, read-path with raw `attributes` map, missing
   `start_time`, overnight intervals, write-path returns
   `SetModelRequest` with correct attribute keys, delete request shape.
2. **`data/action/kgql_action_repository_test.dart`** — `listForDay`,
   `getById`, `upsert`, `delete` against a mocked `GraphQLClient`. The
   "fetch yesterday + today, filter overlap" logic from the current
   `today_repository.dart` belongs here, and is currently exercised
   only by the live integration test.
3. **`features/today/today_view_model_test.dart`** — pure-Dart test
   that takes a `List<Action>` (built via `_support/test_actions.dart`)
   and asserts `titleLine`, segment flexes, current-marker fraction,
   row strings, color stability. Today this code is verified only by
   running the app.
4. **`features/action_edit/action_edit_view_model_test.dart`** —
   validation, create vs edit branching, save → `repo.upsert(action)`
   exactly once, delete → `repo.delete(id)`. Now that the two pages
   merge into one with a mode flag, the view-model is the natural
   place for this logic.
5. **`integration/crud_round_trip_integration_test.dart`** — create an
   Action via `actionRepository`, fetch by id, mutate notes, delete,
   assert it's gone. Mirrors the same recommendation as `nx_db`. Highest
   value integration test we don't have.
6. **`core/theme/action_color_palette_test.dart`** — color stability is
   what made the previous detail-page bug ("sleep is green on list,
   purple on detail") happen. Lock it with a test: same `modelTypeId` →
   same `Color`; pill style derivation deterministic.
7. **`core/formatting/time_format_test.dart` + `date_label_test.dart`** —
   `'9:41 AM'`, `'1h 25m'`, `'00:32:14'`, `'Today — Sat, Apr 18'`. These
   strings are user-visible; lock them.
8. **`features/action_detail/action_detail_page_test.dart`** — Edit
   button is disabled when no source `Action` is present; Notes section
   appears only when `description` non-empty; date renders before pill.
   These are the user-visible regressions the recent CRUD work hit.
9. **`features/today/widgets/time_map_bar_test.dart`** — first golden.
   Validates the segment-bar widget pixel-for-pixel against a fixed
   set of segments. A safe place to start "golden" coverage.
10. **`layering/no_nx_db_in_features_test.dart`** and
    **`layering/no_flutter_in_domain_test.dart`** — scan `lib/features/**`
    for `package:nx_db/`, scan `lib/domain/**` for `package:flutter`,
    `package:flutter_riverpod`, `package:nx_db`. Fail with a list of
    offenders. This is what guarantees the layering doesn't rot, and
    `nx_time_reorg.md` rule #1 / #2 explicitly call for it.

## Principles to enforce

- **Mirror `lib/` exactly.** Finding the test for
  `features/today/today_view_model.dart` should mean opening
  `test/features/today/today_view_model_test.dart`. Anything else is a
  bug.
- **Test at the lowest layer with logic.** Domain types in pure Dart
  tests; data mappers with no Flutter binding; view-models with a
  `ProviderContainer` and a fake repository; widgets with the smallest
  fake graph that pumps. A widget test should never need a mocked
  GraphQLClient — that means logic leaked from the data layer to the
  feature layer.
- **One source file → one test file**, named `<source_filename>_test.dart`.
- **The fake `ActionRepository` is THE testing seam for features.**
  `_support/fake_action_repository.dart` lives in the test tree, takes
  a `List<Action>` constructor, and lets every feature test bypass
  `nx_db` entirely. Screenshot tests use the same fake (just with a
  fixed list).
- **Integration tests are for things only the live server can answer**:
  schema parity with `Action` descendants (current), live aggregate
  paths, CRUD round trip (missing). Anything that can be answered with a
  fake `ActionRepository` does *not* belong there.
- **No test imports `package:nx_time/lib/...`** — only
  `package:nx_time/...`. (Today's tests do this correctly; lock it.)
- **No widget test imports `package:nx_db/...`.** If a widget test needs
  KGQL types, the widget under test is reaching past the domain layer
  and should be refactored.
- **Goldens are opt-in per widget**, not per page initially. Start with
  stable, deterministic widgets (`time_map_bar`, `time_map_segment`).
  Page-level goldens accumulate maintenance cost; reach for them once a
  feature stabilises.
- **Shared mocking goes in `test/_support/`.** Today there are three
  small support files; treat them as a real testing kit.

## Suggested execution order

Mapped 1:1 onto the migration order in `nx_time_reorg.md` so test work
lands in the same step as the code it covers. Each step keeps `flutter
test --exclude-tags=integration` green.

1. **Create `test/_support/`** with `fake_action_repository.dart`,
   `pump_app.dart`, `test_actions.dart`. Adopt a `MockGraphQLClient`
   re-export from `nx_db`'s `_support`. (No code under test needed — pure
   plumbing.)
2. **Add `domain/` tests for `Action`, `ActionCategory`** the moment the
   domain types land (reorg step 1). They are pure Dart, no harness
   needed.
3. **Move `unit/time_kgql_schema_test.dart`** →
   `data/action/action_kgql_struct_test.dart` when reorg renames the
   source file (reorg step 2).
4. **Add `data/action/action_mapper_test.dart`** as soon as the mapper
   is extracted from `today_snapshot_mapper.dart` and
   `activity_detail_models.dart`. Use mocked KGQL `Model` JSON fixtures.
5. **Add `data/action/kgql_action_repository_test.dart`** with a mocked
   `GraphQLClient`. Move all "yesterday + today + overlap" assertions
   here from the live integration test.
6. **Add `features/today/today_view_model_test.dart`** the moment
   `today_view_model.dart` exists (reorg step 3). Fixture domain
   `Action`s in, view-model strings/flexes out.
7. **Add `features/action_edit/action_edit_view_model_test.dart`** when
   the merged page lands (reorg step 4). Validation, create vs edit,
   save → repo.upsert.
8. **Replace `screenshot_today_repository.dart`** with a fake
   `ActionRepository` (reorg step 5). Same content (4 fixed actions),
   different seam. Update `screenshot_auth.dart` accordingly.
9. **Add `layering/` tests** when reorg step 6 calls for an
   `import_lint` rule. Scan-based AST tests are an acceptable
   first-pass; a real lint package can be added later.
10. **Add `widget/` page tests** for the new feature folders as they
    settle. Don't try to hit them all at once — pick the highest-risk
    page each step (start with `action_detail_page` and
    `action_edit_page`).
11. **Add `integration/crud_round_trip_integration_test.dart`** any time
    after step 5; it depends on `kgql_action_repository.dart` being
    real.
12. **Update `dart_test.yaml`** with the new tags; update `test/README.md`
    with the new layout.

After this, `flutter test --exclude-tags=integration` runs the entire
fast suite (domain → data → view-model → widget → golden → layering),
and `RUN_NX_TIME_INTEGRATION=true flutter test test/integration` is the
only thing that needs a backend. `flutter drive --target=tests/screenshot_test.dart`
remains the third tier for visual reference diffs and is unaffected by
this reorg.
