# `nx_time` architecture

This is the entry-point doc for anyone who's never opened `nx_time`
before. Read it once, then keep it open while you make your first
change. Its companion is
[`nx_db/docs/structure.md`](../../nx_db/docs/structure.md), which
explains the shared package this app sits on top of, and
[`nx_db/docs/app_creation.md`](../../nx_db/docs/app_creation.md), which
generalizes this layout into a recipe for new apps.

## What `nx_time` is

A Flutter time-tracking app — Today / Tasks / Goals / Calendar tabs
plus action create/edit and an AI chat. Concretely it is also **the
canonical model prototype** for every future Nexus app: its layering,
folder names, naming conventions, and Riverpod sequence are what other
apps copy. Code that lands here should be willing to be imitated.

## Why this codebase exists

`nx_time` is a Flutter app that talks to the same PGDB GraphQL backend
as every other Nexus app, but the time-tracking domain is its own:
typed `Action`s with start / end times, an action-subtype taxonomy, a
"Today" view that rolls those up into a daily snapshot, a calendar
view, a tasks board, and so on. None of that lives in `nx_db` — it's
specific to this app.

So `nx_time` solves two problems at once:

- **App-specific:** model the time-tracking domain in pure Dart, render
  it with Material, handle local state with Riverpod, and persist it
  through the shared backend.
- **Org-wide:** be a worked example a new app can copy. Future apps
  (`nx_expense`, …) read this code to learn the layering, the
  Riverpod-on-`authProvider` sequence, the test structure, and the
  promotion path into `nx_db`.

The architecture serves both: the layers keep the time-tracking code
honest, and they make the parts that *aren't* time-specific — the
Riverpod setup, the data layer pattern, the test scaffolding — easy to
lift into a new app verbatim.

## How the code is organized

Four top-level folders under `lib/`. They form a strict layering: each
one may import only from itself and the layers above it in this list.

```
lib/
  core/      generic, app-agnostic, Flutter-only utilities (theme, layout, formatting, time, generic widgets)
  domain/    PURE DART — typed entities (Action, Task) and abstract Repository interfaces
  data/      bridges domain ⇄ nx_db; KGQL + Riverpod live HERE and only here
  features/  screens, view-models, feature-local providers; Material + Riverpod allowed
```

The hard rules:

| Layer | May import | MUST NOT import |
|-------|------------|-----------------|
| `core/` | `flutter`, `intl`, pure Dart | `domain/`, `data/`, `features/`, any `package:nx_db/*` |
| `domain/` | pure Dart only | **anything Flutter, Riverpod, or `nx_db`** |
| `data/` | `core/`, `domain/`, `flutter_riverpod`, `graphql_flutter`, `package:nx_db/{auth,kgql,riverpod}.dart` | `features/` |
| `features/` | everything below + `package:nx_db/auth.dart` ONLY | `package:nx_db/{nx_db,kgql,riverpod,internal}.dart`, `graphql_flutter` |

Two of these rules are enforced by **layering tests** that grep
`lib/domain/` and `lib/features/` on every test run — see
[How tests are organized](#how-tests-are-organized) below. They will
fail CI if you accidentally cross a boundary.

The router and app shell sit at the root of `lib/` because they
orchestrate the layers above:

```
lib/
  main.dart    # ProviderScope at the root; runs NexusTimeApp
  app.dart     # MaterialApp.router + theme; the only ConsumerWidget at the top
  router.dart  # GoRouter that listens to authProvider and redirects /login ⇄ /today
```

### What each layer's job is

- **`core/`** — leaf utilities a feature might want: theme colors and
  text styles, layout constants, date/time formatters, wall-clock
  helpers, generic widgets that don't know about `Action` or `Task`.
  Nothing in `core/` calls a repository or imports `nx_db`.
- **`domain/`** — the typed business model. `Action` is a Dart class.
  `ActionRepository` is an `abstract class` with `listForCalendarDay`,
  `getById`, `create`, `update`, `delete`. **Pure Dart** — no
  `package:flutter/`, no `package:flutter_riverpod/`, no
  `package:nx_db/`. This is what makes `Action` cheap to test and
  cheap to promote into `nx_db/kgql/shared/` later.
- **`data/`** — the bridge. KGQL knowledge lives here. Concrete
  repository implementations (`KgqlActionRepository`,
  `KgqlTaskRepository`) take a `GraphQLClient` and schema loaders
  through their constructor — never a Riverpod `Ref` — so they could be
  used outside Riverpod (and so they can be `git mv`'d into `nx_db`
  when the time comes). `data/providers.dart` is the **only** file that
  combines `package:nx_db/auth.dart`, `package:nx_db/riverpod.dart`,
  and the app's repositories into Riverpod providers that `features/`
  consumes.
- **`features/`** — one folder per screen / vertical. Each contains the
  page widget, a view-model that turns domain types into UI-shaped
  data, and feature-local Riverpod providers. Features depend on
  abstract `domain/` repositories (overridden in tests with fakes) and
  on Riverpod providers from `data/providers.dart`. The only `nx_db`
  surface they import is `package:nx_db/auth.dart` (for `User`,
  `BackendPreset`, the sign-out call on `authProvider`).

### How `nx_time` relates to `nx_db`

`nx_db` ships **five** sub-libraries. `nx_time` uses each one from
exactly one place:

| `nx_db` sub-library | Imported by | Purpose in `nx_time` |
|---|---|---|
| `package:nx_db/auth.dart` | `lib/router.dart`, `lib/features/auth/time_login_screen.dart`, `lib/features/shell/nx_app_menu_button.dart`, `lib/data/providers.dart` (for `User`) | Sign-in UI, sign-out button, redirect on auth state, the `User` type used by `authenticatedUserProvider` |
| `package:nx_db/kgql.dart` | `lib/data/action/*`, `lib/data/tasks/*`, `lib/data/schema/*` | `Model`, `ModelType`, `SetModelRequest`, `attrString` / `attrDateTime`, `setKgqlCreate/Update/Delete`, repository functions |
| `package:nx_db/riverpod.dart` | `lib/data/providers.dart`, `lib/data/action/action_schema_provider.dart` | `graphqlClientProvider`, `modelTypeByNameProvider` |
| `package:nx_db/transcript.dart` | _(not used today)_ | Available if a transcript feature is added |
| `package:nx_db/nx_db.dart` | _(not used)_ | The everything-shim; new code prefers the focused sub-libraries |

The directionality is one-way: **`nx_time` imports from `nx_db`,
`nx_db` knows nothing about `nx_time`**. There is no `nx_time` import
anywhere under `nx_db/lib/`.

When something in `nx_time` becomes a candidate for promotion (a
second app needs it), the recipe in
[`nx_db_app_boundary.md`](../../nx_db/plans/current/nx_db_app_boundary.md)
is essentially "`git mv` the four files for that entity into
`nx_db/lib/src/kgql/shared/<entity>/`, add a `lib/<entity>.dart`
re-export, swap imports." The fact that this is mechanical is exactly
why `data/<e>/` repositories must take `GraphQLClient` (not `Ref`) and
why `domain/<e>/` is pure Dart.

## Folder layout in detail

```
nx_time/
  lib/
    main.dart                   # ProviderScope + runApp
    app.dart                    # MaterialApp.router + theme
    router.dart                 # GoRouter; redirect on authProvider

    core/
      theme/
        app_theme.dart                  # buildAppTheme() + AppColors palette
        action_color_palette.dart       # category color lookup
      layout/
        layout.dart                     # spacing constants, RefLayout
      formatting/
        date_label.dart                 # "Today" / "Yesterday" / "Mar 14"
        time_format.dart                # 09:30 / 9:30 AM
      time/
        wall_clock_time.dart            # local wall-clock helpers (KGQL stores naive local times)
        time_window.dart                # interval algebra
      widgets/
        nx_tab_header.dart              # generic section header
        task_row_tile.dart              # generic tile (no business logic)
        task_status_segmented.dart

    domain/                            # PURE DART
      action/
        action.dart                     # Action class (id, name, start, end, …)
        action_repository.dart          # abstract ActionRepository
        action_category.dart            # ActionCategory + computations
      tasks/
        task.dart
        task_repository.dart            # abstract TaskRepository
        task_status.dart                # TaskStatus + KGQL string helpers
      projects/
        project.dart
        project_repository.dart         # abstract ProjectRepository

    data/                              # KGQL + Riverpod ALLOWED HERE
      providers.dart                    # action/task/project repo providers, authenticatedUserProvider
      action/
        action_attr_keys.dart           # const String kActionAttrStartTime = '…';
        action_mapper.dart              # Model ⇄ Action; Action → SetModelRequest
        kgql_action_repository.dart     # implements ActionRepository over GraphQLClient (Ref-free)
        action_schema_provider.dart     # cached ModelType for "Action"
        action_subtypes_provider.dart   # FutureProvider<List<ModelType>> for subtype picker
      tasks/
        task_attr_keys.dart             # `task_tags` stores labels (not `tags` — reserved on Model JSON)
        task_mapper.dart
        kgql_task_repository.dart       # implements TaskRepository
        task_schema_provider.dart
      projects/
        project_attr_keys.dart
        project_mapper.dart
        kgql_project_repository.dart
        project_schema_provider.dart
      schema/
        kgql_action_schema_repository.dart  # cached schema fetcher

    features/                          # SCREENS + view-models
      auth/
        time_login_screen.dart          # the app's own login UI; calls authProvider.notifier.login()
      shell/
        app_shell.dart                  # bottom-nav scaffold; one tab per top-level feature
        nx_app_menu_button.dart         # hamburger w/ sign-out
      today/
        today_page.dart
        today_view_model.dart           # AsyncNotifierProvider<TodaySnapshot>
        widgets/
          activity_row.dart
          time_map_bar.dart
          time_map_segment.dart
          category_legend.dart
      tasks/
        tasks_page.dart                 # plus task_detail / task_picker / task_create / project_drill_*
        task_status.dart                # presentation enum
        task_pick_widgets.dart
      goals/
        goals_page.dart
      calendar/
        calendar_page.dart
        calendar_view_model.dart
      action_edit/
        action_edit_page.dart
        action_edit_view_model.dart
        action_edit_providers.dart      # picker options derived from data/action_subtypes_provider
        action_category_option.dart     # UI-only DTO
        widgets/
          action_category_picker.dart
          action_datetime_picker.dart
      action_detail/
        action_detail_page.dart
        action_detail_view_model.dart
        widgets/
          time_block_bar.dart
          notes_block.dart
          category_pill.dart
          linked_task_row.dart
      ai/
        ai_chat_page.dart
        voice_listening_overlay.dart
      settings/
        action_colors_page.dart
```

A few patterns to notice while reading:

- **`<feature>_view_model.dart` is always a Riverpod provider, never a
  ChangeNotifier or controller class hung off the widget.** Pages
  `ref.watch(...)` it; tests `ProviderContainer` it.
- **`widgets/` subfolders inside features are private to that
  feature.** A widget reused across features moves up to
  `lib/core/widgets/`.
- **`<entity>_attr_keys.dart` is the only place attribute key strings
  are defined.** Mappers and tests both import these constants —
  there are no string literals scattered through the data layer.
- **`<entity>_mapper.dart` is pure functions.** No classes, no
  Riverpod, no I/O. Testable without any harness.
- **`kgql_<entity>_repository.dart` constructors take concrete
  dependencies.** They never accept `Ref` and never call
  `ref.read(...)`. Riverpod resolution happens once, in
  `data/providers.dart`.

## How tests are organized

`test/` mirrors `lib/` exactly — same folder names, same nesting.
**One test file per source file** is the goal; tests live where the
code they cover lives.

```
nx_time/test/
  _support/                          # shared test helpers
    pump_app.dart                    # pumpAppWith({overrides, child}) for widget tests
    riverpod_helpers.dart            # makeContainer({overrides}) for view-model tests
    mock_graphql_client.dart         # mocktail-based MockGql + okQueryResult
    fake_action_repository.dart      # in-memory ActionRepository for view-model / widget tests
    test_actions.dart                # canonical Action fixtures
    screenshot_today_snapshot.dart   # canonical TodaySnapshot for screenshot integration tests
    integration_auth.dart            # TestAuthController + overrides for live-backend tests
    screenshot_auth.dart             # ScreenshotAuthController + overrides for screenshot tests

  core/
    formatting/
      date_label_test.dart
      time_format_test.dart
    theme/
      action_color_palette_test.dart
    time/
      wall_clock_time_test.dart
      time_window_test.dart

  domain/                            # PURE DART tests — no Flutter imports needed
    action/
      action_test.dart
      action_category_test.dart
    tasks/
      task_test.dart
    projects/
      project_test.dart

  data/
    providers_test.dart              # asserts wiring (which class each provider exposes)
    action/
      action_attr_keys_test.dart     # constants survive accidental rename
      action_mapper_test.dart        # Model ⇄ Action round-trips, Set* shape
      kgql_action_repository_test.dart  # mocked GraphQLClient — no Riverpod
      action_kgql_struct_test.dart   # struct-builder shape for the action schema
    schema/
      kgql_action_schema_repository_test.dart
    tasks/
      task_attr_keys_test.dart
      task_mapper_test.dart
      kgql_task_repository_test.dart
    projects/
      project_attr_keys_test.dart
      project_mapper_test.dart
      kgql_project_repository_test.dart

  features/
    today/today_view_model_test.dart           # ProviderContainer + FakeActionRepository
    calendar/calendar_view_model_test.dart
    action_edit/action_edit_view_model_test.dart

  widget/
    login_page_test.dart             # widget tests for screens (uses pumpAppWith)

  layering/                          # GUARD TESTS — copy these into every new app
    no_flutter_in_domain_test.dart   # asserts lib/domain has no flutter / riverpod / nx_db imports
    no_nx_db_in_features_test.dart   # asserts lib/features only imports package:nx_db/auth.dart

  integration/                       # opt-in; live PGDB required
    time_integration_test.dart                  # broad smoke
    crud_round_trip_integration_test.dart       # create → read → update → delete an Action
```

### What each test layer asserts

| Layer | What it tests | Mocks / fakes |
|---|---|---|
| `test/core/` | Pure utilities: formatters, color palette, time math. | none |
| `test/domain/` | Value semantics, derived computations. **Pure Dart.** | none |
| `test/data/<e>/<e>_mapper_test.dart` | `Model` ⇄ `<E>` and `<E>` ⇄ `SetModelRequest` round-trips. | none |
| `test/data/<e>/kgql_<e>_repository_test.dart` | GraphQL contract: which document, which variables, parsing. | `MockGraphQLClient` from `_support/` |
| `test/data/providers_test.dart` | Riverpod wiring (which class each provider returns). | overrides on `graphqlClientProvider` |
| `test/features/<feature>/<x>_view_model_test.dart` | View-model state under various inputs. | `FakeActionRepository` overrides on `actionRepositoryProvider` |
| `test/widget/` | Widget rendering and tap behavior. | `FakeActionRepository` + `pumpAppWith` |
| `test/layering/` | Architectural rules. | reads `lib/` source files, scans imports |
| `test/integration/` | End-to-end with a real backend. | none — requires `RUN_NX_TIME_INTEGRATION=true` |

### Test support helpers

The eight files under `test/_support/` are the kit every other test
file pulls from. Use them; don't reinvent.

- **`pump_app.dart`** — `pumpAppWith(tester, child:..., overrides:...)`
  wraps your widget in `ProviderScope` + `MaterialApp` for widget tests.
- **`riverpod_helpers.dart`** — `makeContainer({overrides})` builds a
  `ProviderContainer` for view-model tests that don't need a widget tree.
- **`mock_graphql_client.dart`** — mocktail `MockGraphQLClient` plus
  helpers like `okQueryResult(data)` to fake `GraphQLClient.query` /
  `mutate` calls cleanly.
- **`fake_action_repository.dart`** — in-memory `ActionRepository` that
  view-model and widget tests use as the override for
  `actionRepositoryProvider`.
- **`test_actions.dart`** — canonical `Action` fixtures so tests
  agree on what "an action at 9am for an hour" looks like.
- **`screenshot_today_snapshot.dart`** — fixed `TodaySnapshot` for
  screenshot integration tests (deterministic pixel output).
- **`integration_auth.dart`** — `TestAuthController` + a
  `timeIntegrationOverrides` list that points the app at
  `kIntegrationTestBackendUrls` (localhost). Plus `runTimeIntegration`
  that gates everything on `RUN_NX_TIME_INTEGRATION=true`.
- **`screenshot_auth.dart`** — `ScreenshotAuthController` (no backend
  ping, no startup delay) + `screenshotAuthOverrides` for screenshot
  tests that need a logged-in user without a network.

### How to run

```bash
flutter test                              # default: skips integration unless tag included
flutter test test/features                # by folder
flutter test test/data/action             # one entity at a time
RUN_NX_TIME_INTEGRATION=true flutter test test/integration   # live backend on localhost
```

Tags are declared in `dart_test.yaml` (mirrors `nx_db`'s convention:
`unit`, `repository`, `provider`, `widget`, `integration`).

### Conventions for new tests

- **Place the test next to its source.** A new file at
  `lib/features/foo/foo_view_model.dart` gets a test at
  `test/features/foo/foo_view_model_test.dart`.
- **Test at the lowest layer that has logic.** A formatter goes in
  `core/`; a `Model` → `Action` transform goes in
  `data/<e>/<e>_mapper_test.dart`; only the GraphQL contract goes in
  `kgql_<e>_repository_test.dart`. Don't test the same logic at three
  layers.
- **Use the fakes, not real KGQL.** View-model and widget tests
  override `<e>RepositoryProvider` with a `Fake<E>Repository`. Hitting
  `GraphQLClient` from a feature test is the wrong layer.
- **Integration tests are opt-in and tagged.** They require
  `RUN_NX_TIME_INTEGRATION=true` and a PGDB on localhost. They never
  block default CI.
- **The two layering tests are non-negotiable.** If you find yourself
  wanting to delete one to make a commit pass, the architecture has
  drifted — fix the import, don't delete the test.

## Where to put new code (and its test)

| You're adding… | Goes in `lib/…` | Test goes in `test/…` |
|---|---|---|
| A new route (`/foo`) | `router.dart` | `widget/<route>_test.dart` if there's UI logic |
| A new top-level screen | `features/<feature>/<feature>_page.dart` | `widget/<feature>_test.dart` for golden / tap tests |
| State for that screen | `features/<feature>/<feature>_view_model.dart` | `features/<feature>/<feature>_view_model_test.dart` |
| Feature-local Riverpod providers (≥2) | `features/<feature>/<feature>_providers.dart` | `features/<feature>/<feature>_providers_test.dart` |
| A widget used by ONE feature | `features/<feature>/widgets/<widget>.dart` | usually covered by the feature widget test |
| A widget reused across features | `core/widgets/<widget>.dart` | `core/widgets/<widget>_test.dart` |
| A typed business object (Action, Task, …) | `domain/<e>/<e>.dart` | `domain/<e>/<e>_test.dart` |
| An abstract repository contract | `domain/<e>/<e>_repository.dart` | (interface only — covered by impl tests) |
| Concrete KGQL implementation of a repo | `data/<e>/kgql_<e>_repository.dart` | `data/<e>/kgql_<e>_repository_test.dart` (`MockGraphQLClient`) |
| `Model` ⇄ entity conversion | `data/<e>/<e>_mapper.dart` | `data/<e>/<e>_mapper_test.dart` |
| KGQL attribute key constants | `data/<e>/<e>_attr_keys.dart` | `data/<e>/<e>_attr_keys_test.dart` (rename guard) |
| Riverpod binding for a repository | `data/providers.dart` | extend `data/providers_test.dart` |
| A schema fetcher / cache | `data/<e>/<e>_schema_provider.dart` or `data/schema/<x>_repository.dart` | `data/<e>/<x>_test.dart` |
| Sign-in UI tweak | `features/auth/time_login_screen.dart` | `widget/login_page_test.dart` |
| Sign-out / app-menu UI | `features/shell/nx_app_menu_button.dart` | `widget/<x>_test.dart` if needed |
| Theme color, text style, spacing | `core/theme/…` or `core/layout/…` | `core/theme/<x>_test.dart` if non-trivial |
| Date / number / time formatter | `core/formatting/<x>.dart` or `core/time/<x>.dart` | `core/{formatting,time}/<x>_test.dart` |
| A new GraphQL operation | **not in `nx_time`** — add to `nx_db/lib/src/kgql/documents/` | test in `nx_db/test/kgql/documents/` |
| A typed entity needed by another app | **promote to `nx_db/lib/src/kgql/shared/<e>/`** — see `nx_db_app_boundary.md` | tests move with the code |
| Anything that imports `package:nx_db/kgql.dart` from a feature | **stop** — move the KGQL-aware piece into `data/`, expose a domain-shaped provider, consume that from the feature | n/a |

### The decision question

When you're unsure where something belongs, ask in this order:

1. **Does it touch `Model`, `ModelType`, `SetModelRequest`, or
   `GraphQLClient`?** If yes, it's `data/`. (Or it's a candidate for
   a `nx_db/kgql/helpers/` promotion — see
   [`nx_db_app_boundary.md`](../../nx_db/plans/current/nx_db_app_boundary.md).)
2. **Is it pure Dart with no Flutter, no Riverpod, no `nx_db`?** That's
   `domain/`.
3. **Does it render pixels or hold UI state for a specific screen?**
   That's `features/<feature>/`.
4. **Is it a generic helper that any feature might want and that knows
   nothing about Action / Task / the backend?** That's `core/`.
5. **Does the answer involve a second Nexus app needing the same
   thing?** It's a promotion candidate for `nx_db` — pause and re-read
   `nx_db/docs/app_creation.md` §5 before adding it here.

If you keep the layering honest and the test goes in the same path
under `test/` as the source under `lib/`, the next person who opens
`nx_time` — even months from now — won't have to guess where anything
is.
