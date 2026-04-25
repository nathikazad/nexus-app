# `nx_projects` architecture

This is the entry-point doc for anyone who's never opened `nx_projects`
before. Read it once, then keep it open while you make your first
change. Its companions are
[`nx_db/docs/structure.md`](../../nx_db/docs/structure.md), which
explains the shared package this app sits on top of,
[`nx_db/docs/app_creation.md`](../../nx_db/docs/app_creation.md), which
generalizes this layout into a recipe for new apps, and
[`nx_time/docs/arch.md`](../../nx_time/docs/arch.md), the canonical
prototype `nx_projects` follows.

## What `nx_projects` is

A Flutter project-and-sprint planner — Priority / Projects / Sprint /
Daily tabs plus task create / edit, drill-down navigation through
projects → sub-projects → tasks, sprint capacity planning by day, and
a daily focus view. It runs on phone *and* desktop from the same code:
the four tabs are the same screens, only the chrome around them
differs.

The HTML/CSS reference prototypes live under `reference/` and are the
visual source of truth while the Flutter app is being built:

```
reference/
  desktop/    # multi-pane planner: left list, center week board, right sprint cart
  mobile/     # bottom-nav single-pane planner with drill-down
```

## Why this codebase exists

`nx_projects` is a Flutter app that talks to the same PGDB GraphQL
backend as every other Nexus app, but the project-planning domain is
its own: typed `Project`s, `Task`s with `kind` (feature / bug),
`bucket` (now / next / later / someday), `Sprint`s with capacity and
day-by-day planning, and the priority/sprint/daily roll-ups. None of
that lives in `nx_db` — it's specific to this app.

So `nx_projects` solves two problems at once:

- **App-specific:** model the planner domain in pure Dart, render it
  with Material on phone and desktop from one set of widgets, handle
  local state with Riverpod, and persist through the shared backend.
- **Org-wide:** be the second worked example (after `nx_time`) and the
  first one that ships a *responsive* shell. Future apps that need
  both phone and desktop UIs read this code to learn the
  responsive-shell pattern.

The architecture serves both: the layers keep the planner code honest,
and the shell split (`features/shell/` for mobile, `features/desktop/`
for desktop) is easy to lift verbatim into a new app.

## How the code is organized

Four top-level folders under `lib/`. They form a strict layering: each
one may import only from itself and the layers above it in this list.

```
lib/
  core/      generic, app-agnostic, Flutter-only utilities (theme, layout, formatting, time, generic widgets)
  domain/    PURE DART — typed entities (Project, Task, Sprint, Bucket) and abstract Repository interfaces
  data/      bridges domain ⇄ nx_db; KGQL + Riverpod live HERE and only here
  features/  screens, view-models, feature-local providers; Material + Riverpod allowed
```

The hard rules:

| Layer | May import | MUST NOT import |
|-------|------------|-----------------|
| `core/` | `flutter`, `intl`, pure Dart | `domain/`, `data/`, `features/`, any `package:nx_db/*` |
| `domain/` | pure Dart only | **anything Flutter, Riverpod, or `nx_db`** |
| `data/` | `core/`, `domain/`, `flutter_riverpod`, `graphql_flutter`, `package:nx_db/{auth,kgql,riverpod,person,transcript}.dart` | `features/` |
| `features/` | everything below + `package:nx_db/{auth,person,transcript}.dart` | `package:nx_db/{nx_db,kgql,riverpod,internal}.dart`, `graphql_flutter` |

Two of these rules are enforced by **layering tests** that grep
`lib/domain/` and `lib/features/` on every test run — see
[How tests are organized](#how-tests-are-organized) below. They will
fail CI if you accidentally cross a boundary.

The router and app shell sit at the root of `lib/` because they
orchestrate the layers above:

```
lib/
  main.dart    # ProviderScope at the root; runs NexusProjectsApp
  app.dart     # MaterialApp.router + theme; the only ConsumerWidget at the top
  router.dart  # GoRouter that listens to authProvider and switches mobile/desktop shell by viewport
```

### What each layer's job is

- **`core/`** — leaf utilities a feature might want: theme colors and
  text styles, layout constants, date/time formatters, wall-clock
  helpers, generic widgets that don't know about `Project` or `Task`,
  and the `isDesktopLayout(context)` helper that gates the dual-shell
  switch. Nothing in `core/` calls a repository or imports `nx_db`.
- **`domain/`** — the typed business model. `Project`, `Task`,
  `Sprint`, `Bucket`, `TaskStatus`, `TaskKind` are Dart classes / enums.
  `ProjectRepository`, `TaskRepository`, `SprintRepository` are
  `abstract class`es with the operations each screen needs. **Pure
  Dart** — no `package:flutter/`, no `package:flutter_riverpod/`, no
  `package:nx_db/`. This is what makes the entities cheap to test and
  cheap to promote into `nx_db/kgql/shared/` later.
- **`data/`** — the bridge. KGQL knowledge lives here. Concrete
  repository implementations (`KgqlProjectRepository`,
  `KgqlTaskRepository`, `KgqlSprintRepository`) take a `GraphQLClient`
  and schema loaders through their constructor — never a Riverpod
  `Ref` — so they could be used outside Riverpod (and so they can be
  `git mv`'d into `nx_db` when the time comes). `data/providers.dart`
  is the **only** file that combines `package:nx_db/auth.dart`,
  `package:nx_db/riverpod.dart`, and the app's repositories into
  Riverpod providers that `features/` consumes.
- **`features/`** — one folder per screen / vertical. Each contains the
  page widget, a view-model that turns domain types into UI-shaped
  data, and feature-local Riverpod providers. Features depend on
  abstract `domain/` repositories (overridden in tests with fakes) and
  on Riverpod providers from `data/providers.dart`. The only `nx_db`
  surface they may import is `package:nx_db/auth.dart` (for `User`,
  `BackendPreset`, sign-out) and, when a screen needs types from shared
  user modules, `package:nx_db/person.dart` and/or
  `package:nx_db/transcript.dart`.

### How `nx_projects` relates to `nx_db`

`nx_db` ships **six** sub-libraries (plus the everything-shim).
`nx_projects` uses each one from the right layer:

| `nx_db` sub-library | Imported by | Purpose in `nx_projects` |
|---|---|---|
| `package:nx_db/auth.dart` | `lib/router.dart`, `lib/features/auth/projects_login_screen.dart`, `lib/features/shell/nx_app_menu_button.dart`, `lib/data/providers.dart` | Sign-in UI, sign-out button, redirect on auth state, the `User` type used with `authProvider` / `authenticatedUserProvider` |
| `package:nx_db/kgql.dart` | `lib/data/project/*`, `lib/data/task/*`, `lib/data/sprint/*`, `lib/data/schema/*` | `Model`, `ModelType`, `SetModelRequest`, `attrString` / `attrDateTime` / `attrInt`, `setKgqlCreate/Update/Delete`, repository functions |
| `package:nx_db/riverpod.dart` | `lib/data/providers.dart`, `lib/data/*/`*`_schema_provider.dart` | `graphqlClientProvider`, `modelTypeByNameProvider` |
| `package:nx_db/person.dart` | `lib/data/providers.dart` (re-export) | `Person`, `PersonRepository`, `mainPersonProvider`, `personRepositoryProvider`, `personSchemaProvider` — current user's profile + JSON `preference` (e.g. project color overrides) |
| `package:nx_db/transcript.dart` | _(not used in nx_projects today)_ | Same pattern for current transcript if/when a screen needs it |
| `package:nx_db/nx_db.dart` | _(not used)_ | The everything-shim; new code prefers the focused sub-libraries |

The directionality is one-way: **`nx_projects` imports from `nx_db`,
`nx_db` knows nothing about `nx_projects`**. There is no `nx_projects`
import anywhere under `nx_db/lib/`.

### The dual-shell (mobile + desktop) pattern

This is what's new in `nx_projects` versus `nx_time`. The same tab
screens render on phone and desktop; only the surrounding chrome
differs. The mechanism is the one `nx_expense` proved out:

1. **Each tab is one `*_screen.dart` widget that takes an `embedded`
   flag.** When `embedded: false` (mobile default) it renders its own
   `Scaffold` with title and FAB. When `embedded: true` it returns
   just the panel body, wrapped by a `PanelChrome` from
   `features/desktop/panel_chrome.dart` that supplies title / actions.
2. **`router.dart` switches by viewport, not by feature.** A
   `StatefulShellRoute.indexedStack` provides the four branches
   (Priority / Projects / Sprint / Daily) to both shells. At build
   time, `isDesktopLayout(context)` (from `core/layout/`) picks
   `MobileShell` (Scaffold + bottom `NavigationBar` + FAB) or
   `DesktopShell` (Stack with the branch tree off-stage and a
   panel layout in front, driven by `NavigationRail`).
3. **`features/desktop/desktop_shell.dart` composes the same screens
   into multi-pane layouts.** Projects tab on desktop = `ProjectsScreen`
   (list panel) + `ProjectDetailScreen` (centre) + `TaskDetailPanel`
   (right). All three are the same widgets the mobile shell pushes as
   full pages.
4. **Selection is shared state, not navigation.** A
   `selectedProjectIdProvider` / `selectedTaskIdProvider` lives in
   `features/shell/selection_providers.dart`. Mobile ignores them and
   pushes routes; desktop reads them and rebuilds the right pane. One
   source of truth, two presentations.

```
features/
  shell/         # MOBILE shell — bottom nav, FAB, route push for drill-down
  desktop/       # DESKTOP shell — NavigationRail, panel composition, PanelChrome
  priority/      # tab screen, used by both shells
  projects/      # tab screen + drill-down screens, used by both shells
  sprint/        # tab screen, used by both shells
  daily/         # tab screen, used by both shells
  task_detail/   # detail screen — full page on mobile, right panel on desktop
  task_edit/     # bottom-sheet on mobile, dialog on desktop
```

### When the body itself differs (view-shape)

The default (`embedded` flag + `PanelChrome`) only handles **chrome**
differences: Scaffold vs panel wrapper, title bar, FAB, etc. When the
*body* of a tab differs in density, layout, or interaction model
between `reference/mobile/` and `reference/desktop/` (e.g. mobile
drill-down vs desktop dense table rows, or a full project tree in one
pane), use the **view-shape** recipe.

1. **Keep one `*_screen.dart` per tab** (so the layering test
   `no_dual_codepath_test` still passes: both shells import the same
   screen file).
2. **Inside the screen, branch on** `isDesktopLayout(context)` **from
   `core/layout/is_desktop_layout.dart`**, and return
   `Desktop<Feature>Body(...)` or `Mobile<Feature>Body(...)`. Each body
   lives next to the screen as `mobile_<feature>_body.dart` and
   `desktop_<feature>_body.dart`.
3. **Share view-model state and providers** — `ref.watch` the same
   `*ViewModel` / notifiers; only the widget tree that maps domain data
   to pixels differs.
4. **Domain-aware widgets shared across features** (e.g. a dense
   `DesktopTaskRow` that knows about `Task` / `TaskKind` / `TaskBucket`)
   go in `lib/features/shared/widgets/`. The layering rule
   **`core/` must not import `domain/`** means those rows cannot live
   under `core/widgets/`; only *generic* (business-agnostic) widgets do.

The `embedded` flag and `PanelChrome` are still the right way to
switch *chrome* when the **inner body is the same** on both form
factors. When the **body** diverges, the screen picks a mobile or
desktop **body** widget as above; view-model and selection providers
remain one source of truth.

When something in `nx_projects` becomes a candidate for **generic**
cross-app promotion, the recipe in
[`nx_db_app_boundary.md`](../../nx_db/plans/current/nx_db_app_boundary.md)
is essentially "`git mv` the four files for that entity into
`nx_db/lib/src/kgql/shared/<entity>/`, add a `lib/<entity>.dart`
re-export, swap imports."

## Folder layout in detail

```
nx_projects/
  reference/
    desktop/                           # static HTML/CSS prototype of the desktop planner
    mobile/                            # static HTML/CSS prototype of the mobile planner

  lib/
    main.dart                          # ProviderScope + runApp
    app.dart                           # MaterialApp.router + theme
    router.dart                        # GoRouter; switches MobileShell/DesktopShell on isDesktopLayout

    core/
      theme/
        app_theme.dart                  # buildAppTheme() + AppColors palette (matches reference/* dark theme)
        bucket_color_palette.dart       # now/next/later/someday → Color
        kind_color_palette.dart         # feat/bug → Color
        status_color_palette.dart       # todo/doing/blocked/done → Color
      layout/
        layout.dart                     # spacing constants
        is_desktop_layout.dart          # isDesktopLayout(BuildContext) — viewport gate for the dual shell
      formatting/
        date_label.dart                 # "Today" / "Yesterday" / "Apr 25"
        sprint_window_label.dart        # "Apr 20 – Apr 26 · 4 days left"
        hours_format.dart               # "32h" / "1.5h"
      time/
        wall_clock_time.dart            # KGQL stores naive local times — same helpers as nx_time
        sprint_window.dart              # start + length → days, isToday, contains(date)
      widgets/
        nx_tab_header.dart              # generic section header
        capacity_bar.dart               # stacked done/doing/blocked/todo segments
        progress_dots.dart              # sprint dots ··●··
        kbd_chip.dart                   # generic keyboard shortcut chip (desktop only, but rendered cross-shell)

    domain/                            # PURE DART
      project/
        project.dart                    # Project (id, name, color, parentId, …)
        sub_project.dart                # SubProject (or Project with parentId — choose at design time)
        project_repository.dart         # abstract ProjectRepository
      task/
        task.dart                       # Task (id, projectId, subId?, kind, bucket, sev, est, status, sprintId?, plannedFor?)
        task_kind.dart                  # enum TaskKind { feat, bug }
        task_bucket.dart                # enum TaskBucket { now, next, later, someday }
        task_status.dart                # enum TaskStatus { todo, doing, blocked, done } + KGQL string helpers
        task_severity.dart              # enum TaskSeverity { p0, p1, p2 }
        task_repository.dart            # abstract TaskRepository
      sprint/
        sprint.dart                     # Sprint (id, name, start, length, capH, state)
        sprint_state.dart               # enum SprintState { planned, active, done }
        sprint_repository.dart          # abstract SprintRepository

    data/                              # KGQL + Riverpod ALLOWED HERE
      providers.dart                    # re-exports `package:nx_db/person` + repos + selection providers' deps
      project/
        project_attr_keys.dart          # const String kProjectAttrName = '…'; etc.
        project_mapper.dart             # Model ⇄ Project; Project → SetModelRequest
        kgql_project_repository.dart    # implements ProjectRepository over GraphQLClient (Ref-free)
        project_schema_provider.dart
      task/
        task_attr_keys.dart             # `task_tags` (not `tags` — reserved on Model JSON), `task_bucket`, `task_kind`, etc.
        task_mapper.dart
        kgql_task_repository.dart       # implements TaskRepository
        task_schema_provider.dart
      sprint/
        sprint_attr_keys.dart
        sprint_mapper.dart
        kgql_sprint_repository.dart
        sprint_schema_provider.dart
      person/
        project_color_prefs.dart        # nx_projects-specific Person.preference slice (project color overrides)
      schema/
        kgql_projects_schema_repository.dart  # cached schema fetcher

    features/                          # SCREENS + view-models — same *screen* file per tab for both shells
      shared/                           # widgets reused across *features* that know domain types (not core/ — no domain in core)
        widgets/                        # e.g. task_row, desktop_task_row (Task-aware)
      auth/
        projects_login_screen.dart      # the app's own login UI; calls authProvider.notifier.login()
      shell/
        mobile_shell.dart               # MOBILE: Scaffold + bottom NavigationBar + FAB
        nx_app_menu_button.dart         # hamburger w/ sign-out (used by both shells)
        selection_providers.dart        # selectedProjectIdProvider, selectedTaskIdProvider, selectedDateProvider
      desktop/
        desktop_shell.dart              # DESKTOP: Stack with off-stage branch tree + NavigationRail-driven panels
        desktop_nav.dart                # NavigationRail destinations
        panel_chrome.dart               # title + leading + actions wrapper for embedded screens
        panels/
          priority_panels.dart          # composes BucketListScreen + BucketTasksScreen + sprint cart
          projects_panels.dart          # composes ProjectsScreen + ProjectDetailScreen + TaskDetailPanel
          sprint_panels.dart            # composes BacklogScreen + SprintWeekScreen + sprint cart
          daily_panels.dart             # composes DailyScreen + sprint cart
      priority/
        priority_screen.dart            # isDesktopLayout ? desktop_priority_body : mobile_priority_body
        mobile_priority_body.dart        # mobile drill-down bucket list → bucket tasks
        desktop_priority_body.dart      # all buckets stacked, dense rows (reference/desktop pane-priority)
        bucket_tasks_screen.dart        # tasks-in-bucket — full page on mobile, panel on desktop
        priority_view_model.dart        # AsyncNotifierProvider<PriorityState>
      projects/
        projects_screen.dart            # isDesktopLayout ? desktop_projects_body : mobile_projects_body
        mobile_projects_body.dart        # list → project / subproject drill-down
        desktop_projects_body.dart      # indented project tree (reference/desktop pane-projects)
        project_detail_screen.dart      # project → sub-projects + tasks
        sub_project_detail_screen.dart  # sub-project → tasks
        projects_view_model.dart
        widgets/
          project_row.dart
          progress_bar_with_segments.dart
      sprint/
        sprint_screen.dart              # isDesktopLayout ? desktop_sprint_body : mobile_sprint_body
        mobile_sprint_body.dart         # day-by-day list, capacity
        desktop_sprint_body.dart        # sprint summary strip, bordered day cards (reference/desktop days)
        sprint_view_model.dart
        widgets/
          sprint_day_column.dart        # one day on desktop / one expanded day on mobile
          sprint_cart.dart              # right-rail cart (also used by desktop panels)
          capacity_block.dart
      daily/
        daily_screen.dart               # isDesktopLayout ? desktop_daily_body : mobile_daily_body
        mobile_daily_body.dart          # one day's tasks + summary chips
        desktop_daily_body.dart         # two-column day page + journal (reference/desktop today)
        daily_view_model.dart
        widgets/
          daily_summary_chips.dart
      task_detail/
        task_detail_screen.dart         # full page on mobile, right panel on desktop (embedded:true)
        task_detail_view_model.dart
        widgets/
          status_segmented.dart
          bucket_picker.dart
          sprint_assign_picker.dart
      task_edit/
        task_edit_screen.dart           # bottom-sheet on mobile, dialog on desktop
        task_edit_view_model.dart
        task_edit_providers.dart
      filters/
        filter_sheet.dart               # mobile bottom-sheet; desktop dropdown
        filter_state_providers.dart     # kind / status / search query — shared across tabs
      settings/
        project_colors_page.dart
```

A few patterns to notice while reading:

- **`<feature>_view_model.dart` is always a Riverpod provider, never a
  ChangeNotifier or controller class hung off the widget.** Pages
  `ref.watch(...)` it; tests `ProviderContainer` it.
- **Each feature screen may take `embedded: false` and a `PanelChrome`
  wraps it when the body is the same on both form factors.** If the
  body uses view-shape (mobile vs desktop body widgets), the inner
  content **does** change — still one `*_screen.dart` file, two body
  files. See [When the body itself differs (view-shape)](#when-the-body-itself-differs-view-shape).
- **Drill-down on mobile = selection state on desktop.** The same
  `selectedProjectIdProvider` is read by `ProjectDetailScreen`. Mobile
  pushes a route that sets it; desktop sets it from a tap on the list
  panel and rebuilds the centre panel. Don't write two code paths.
- **`widgets/` subfolders inside features are private to that
  feature.** A widget reused across features and **domain-agnostic**
  (no `Project` / `Task` / `Sprint` types) moves up to
  `lib/core/widgets/`. A widget reused across features that **is**
  domain-aware (e.g. `TaskRow`, `DesktopTaskRow`) lives in
  `lib/features/shared/widgets/` — `core/` may not import `domain/`.
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
nx_projects/test/
  _support/                            # shared test helpers
    pump_app.dart                      # pumpAppWith({overrides, child}) for widget tests
    pump_desktop.dart                  # pumpDesktopWith — same but forces a desktop viewport for shell tests
    riverpod_helpers.dart              # makeContainer({overrides}) for view-model tests
    mock_graphql_client.dart           # mocktail-based MockGql + okQueryResult
    fake_project_repository.dart       # in-memory ProjectRepository
    fake_task_repository.dart          # in-memory TaskRepository
    fake_sprint_repository.dart        # in-memory SprintRepository
    test_projects.dart                 # canonical Project fixtures
    test_tasks.dart                    # canonical Task fixtures
    test_sprints.dart                  # canonical Sprint fixtures
    integration_auth.dart              # TestAuthController + overrides for live-backend tests
    screenshot_auth.dart               # ScreenshotAuthController + overrides for screenshot tests

  core/
    formatting/
      date_label_test.dart
      sprint_window_label_test.dart
      hours_format_test.dart
    layout/
      is_desktop_layout_test.dart
    theme/
      bucket_color_palette_test.dart
      status_color_palette_test.dart
    time/
      sprint_window_test.dart
      wall_clock_time_test.dart

  domain/                              # PURE DART tests — no Flutter imports needed
    project/
      project_test.dart
    task/
      task_test.dart
      task_status_test.dart
      task_bucket_test.dart
    sprint/
      sprint_test.dart

  data/
    providers_test.dart                # asserts wiring (which class each provider exposes)
    project/
      project_attr_keys_test.dart      # constants survive accidental rename
      project_mapper_test.dart         # Model ⇄ Project round-trips, Set* shape
      kgql_project_repository_test.dart  # mocked GraphQLClient — no Riverpod
    task/
      task_attr_keys_test.dart
      task_mapper_test.dart
      kgql_task_repository_test.dart
    sprint/
      sprint_attr_keys_test.dart
      sprint_mapper_test.dart
      kgql_sprint_repository_test.dart
    schema/
      kgql_projects_schema_repository_test.dart

  features/
    priority/priority_view_model_test.dart        # ProviderContainer + Fake*Repository
    projects/projects_view_model_test.dart
    sprint/sprint_view_model_test.dart
    daily/daily_view_model_test.dart
    task_detail/task_detail_view_model_test.dart
    task_edit/task_edit_view_model_test.dart

  widget/
    login_page_test.dart
    mobile_shell_test.dart             # bottom nav, FAB visibility per tab
    desktop_shell_test.dart            # NavigationRail + panel composition; uses pumpDesktopWith
    embedded_screens_test.dart         # asserts each tab screen renders cleanly with embedded:true

  layering/                            # GUARD TESTS — copy these into every new app
    no_flutter_in_domain_test.dart     # asserts lib/domain has no flutter / riverpod / nx_db imports
    no_nx_db_in_features_test.dart     # asserts lib/features only imports package:nx_db/auth.dart (+ person/transcript)
    no_dual_codepath_test.dart         # asserts each tab screen file is referenced by both shells

  integration/                         # opt-in; live PGDB required
    projects_integration_test.dart                # broad smoke
    crud_round_trip_integration_test.dart         # create → read → update → delete a Task
    sprint_planning_integration_test.dart         # plan + reassign tasks within a sprint
```

### What each test layer asserts

| Layer | What it tests | Mocks / fakes |
|---|---|---|
| `test/core/` | Pure utilities: formatters, color palettes, sprint-window math, viewport gate. | none |
| `test/domain/` | Value semantics, derived computations (e.g. progress from task statuses). **Pure Dart.** | none |
| `test/data/<e>/<e>_mapper_test.dart` | `Model` ⇄ `<E>` and `<E>` ⇄ `SetModelRequest` round-trips. | none |
| `test/data/<e>/kgql_<e>_repository_test.dart` | GraphQL contract: which document, which variables, parsing. | `MockGraphQLClient` from `_support/` |
| `test/data/providers_test.dart` | Riverpod wiring (which class each provider returns). | overrides on `graphqlClientProvider` |
| `test/features/<feature>/<x>_view_model_test.dart` | View-model state under various inputs (filters, drill-down, selection). | `Fake*Repository` overrides |
| `test/widget/mobile_shell_test.dart` | Bottom-nav presence, FAB only on Projects detail, sheet open/close. | `Fake*Repository` + `pumpAppWith` |
| `test/widget/desktop_shell_test.dart` | NavigationRail destinations, panel composition per tab, selection updates the right pane. | `Fake*Repository` + `pumpDesktopWith` |
| `test/widget/embedded_screens_test.dart` | Every tab screen renders without throwing under `embedded: true`. | `Fake*Repository` |
| `test/layering/` | Architectural rules. | reads `lib/` source files, scans imports |
| `test/integration/` | End-to-end with a real backend. | none — requires `RUN_NX_PROJECTS_INTEGRATION=true` |

### Test support helpers

The files under `test/_support/` are the kit every other test file
pulls from. Use them; don't reinvent.

- **`pump_app.dart`** — `pumpAppWith(tester, child:..., overrides:...)`
  wraps your widget in `ProviderScope` + `MaterialApp` for widget
  tests at the default (mobile) viewport.
- **`pump_desktop.dart`** — same, but sets `tester.view.physicalSize`
  to a desktop viewport so `isDesktopLayout(context)` returns `true`.
  Use this for any test that exercises `DesktopShell` or panel
  composition.
- **`riverpod_helpers.dart`** — `makeContainer({overrides})` builds a
  `ProviderContainer` for view-model tests that don't need a widget tree.
- **`mock_graphql_client.dart`** — mocktail `MockGraphQLClient` plus
  `okQueryResult(data)` to fake `GraphQLClient.query` / `mutate` calls.
- **`fake_project_repository.dart`** / **`fake_task_repository.dart`** /
  **`fake_sprint_repository.dart`** — in-memory repositories that
  view-model and widget tests use as overrides for the
  `*RepositoryProvider`s.
- **`test_projects.dart` / `test_tasks.dart` / `test_sprints.dart`** —
  canonical fixtures so tests agree on what "a sprint of 7 days with
  40h capacity" looks like.
- **`integration_auth.dart`** — `TestAuthController` + a
  `projectsIntegrationOverrides` list that points the app at
  `kIntegrationTestBackendUrls` (localhost). Plus
  `runProjectsIntegration` that gates everything on
  `RUN_NX_PROJECTS_INTEGRATION=true`.
- **`screenshot_auth.dart`** — `ScreenshotAuthController` (no backend
  ping, no startup delay) + `screenshotAuthOverrides` for screenshot
  tests that need a logged-in user without a network.

### How to run

```bash
flutter test                                                         # default: skips integration
flutter test test/features                                           # by folder
flutter test test/data/task                                          # one entity at a time
flutter test test/widget/desktop_shell_test.dart                     # desktop shell only
RUN_NX_PROJECTS_INTEGRATION=true flutter test test/integration       # live backend on localhost
```

Tags are declared in `dart_test.yaml` (mirrors `nx_db`'s convention:
`unit`, `repository`, `provider`, `widget`, `integration`).

### Conventions for new tests

- **Place the test next to its source.** A new file at
  `lib/features/sprint/sprint_view_model.dart` gets a test at
  `test/features/sprint/sprint_view_model_test.dart`.
- **Test at the lowest layer that has logic.** A formatter goes in
  `core/`; a `Model` → `Task` transform goes in
  `data/task/task_mapper_test.dart`; only the GraphQL contract goes
  in `kgql_task_repository_test.dart`. Don't test the same logic at
  three layers.
- **Use the fakes, not real KGQL.** View-model and widget tests
  override `*RepositoryProvider` with a `Fake*Repository`. Hitting
  `GraphQLClient` from a feature test is the wrong layer.
- **Test the screen once, regardless of shell.** A
  `ProjectDetailScreen` test pumps the screen directly. The
  shell-level tests assert composition, not screen internals — don't
  duplicate.
- **Integration tests are opt-in and tagged.** They require
  `RUN_NX_PROJECTS_INTEGRATION=true` and a PGDB on localhost. They
  never block default CI.
- **The three layering tests are non-negotiable.** If you find yourself
  wanting to delete one to make a commit pass, the architecture has
  drifted — fix the import (or the dual-codepath), don't delete the test.

## Where to put new code (and its test)

| You're adding… | Goes in `lib/…` | Test goes in `test/…` |
|---|---|---|
| A new route (`/foo`) | `router.dart` | `widget/<route>_test.dart` if there's UI logic |
| A new top-level tab | `features/<feature>/<feature>_screen.dart` + branch in `router.dart` + entry in `desktop/desktop_nav.dart` + panel composer in `desktop/panels/` | `widget/<feature>_test.dart` plus updates to `desktop_shell_test.dart` |
| A drill-down inside an existing tab | new screen in same `features/<feature>/`, push it on mobile, set selection provider on desktop | feature view-model test |
| State for a screen | `features/<feature>/<feature>_view_model.dart` | `features/<feature>/<feature>_view_model_test.dart` |
| Feature-local Riverpod providers (≥2) | `features/<feature>/<feature>_providers.dart` | `features/<feature>/<feature>_providers_test.dart` |
| A widget used by ONE feature | `features/<feature>/widgets/<widget>.dart` | usually covered by the feature widget test |
| A widget reused across features, **domain-agnostic** | `core/widgets/<widget>.dart` | `core/widgets/<widget>_test.dart` |
| A widget reused across features, **knows Project/Task/Sprint** | `features/shared/widgets/<widget>.dart` | `test/features/shared/widgets/<widget>_test.dart` (or feature tests) |
| Per-shell **body** of a tab when view-shape diverges (mobile vs desktop) | `features/<feature>/mobile_<feature>_body.dart` and `features/<feature>/desktop_<feature>_body.dart` | `test/features/<feature>/…_body_test.dart` |
| Desktop-only chrome (rail, panel wrapper) | `features/desktop/<x>.dart` | `widget/desktop_shell_test.dart` |
| Mobile-only chrome (bottom nav, FAB) | `features/shell/<x>.dart` | `widget/mobile_shell_test.dart` |
| Cross-tab selection state (project, task, date) | `features/shell/selection_providers.dart` | `features/shell/selection_providers_test.dart` |
| A typed business object (Project, Task, Sprint…) | `domain/<e>/<e>.dart` (not `Person` — use `package:nx_db/person.dart`) | `domain/<e>/<e>_test.dart` |
| An abstract repository contract | `domain/<e>/<e>_repository.dart` | (interface only — covered by impl tests) |
| Concrete KGQL implementation of a repo | `data/<e>/kgql_<e>_repository.dart` | `data/<e>/kgql_<e>_repository_test.dart` (`MockGraphQLClient`) |
| `Model` ⇄ entity conversion | `data/<e>/<e>_mapper.dart` | `data/<e>/<e>_mapper_test.dart` |
| KGQL attribute key constants | `data/<e>/<e>_attr_keys.dart` | `data/<e>/<e>_attr_keys_test.dart` (rename guard) |
| Riverpod binding for a repository | `data/providers.dart` | extend `data/providers_test.dart` |
| A schema fetcher / cache | `data/<e>/<e>_schema_provider.dart` or `data/schema/<x>_repository.dart` | `data/<e>/<x>_test.dart` |
| Sign-in UI tweak | `features/auth/projects_login_screen.dart` | `widget/login_page_test.dart` |
| Sign-out / app-menu UI | `features/shell/nx_app_menu_button.dart` | `widget/<x>_test.dart` if needed |
| Theme color, text style, spacing | `core/theme/…` or `core/layout/…` | `core/theme/<x>_test.dart` if non-trivial |
| Date / sprint / hours formatter | `core/formatting/<x>.dart` or `core/time/<x>.dart` | `core/{formatting,time}/<x>_test.dart` |
| A new GraphQL operation | **not in `nx_projects`** — add to `nx_db/lib/src/kgql/documents/` | test in `nx_db/test/kgql/documents/` |
| A typed entity needed by another app (many rows, generic) | **promote to `nx_db/lib/src/kgql/shared/<e>/`** — see `nx_db_app_boundary.md` | tests move with the code |
| A current-user record shared by all apps (e.g. `Person`, `Transcript`) | **already in** `package:nx_db/person.dart` / `transcript.dart` | tests live in `nx_db` |
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
4. **Is it about *how the tab screens are arranged* on phone or
   desktop?** That's `features/shell/` (mobile) or `features/desktop/`
   (desktop). The screen itself stays in `features/<feature>/`.
5. **Is it a generic helper that any feature might want and that knows
   nothing about Project / Task / Sprint / the backend?** That's
   `core/`.
6. **Does the answer involve a second Nexus app needing the same
   thing?** It's a promotion candidate for `nx_db` — pause and re-read
   `nx_db/docs/app_creation.md` §5 before adding it here.

If you keep the layering honest, keep one screen widget per tab (not
two), and put the test in the same path under `test/` as the source
under `lib/`, the next person who opens `nx_projects` — even months
from now — won't have to guess where anything is.
