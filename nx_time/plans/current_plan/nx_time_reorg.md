# `nx_time` reorganization plan

Goal: a clean separation between **model layer** (what the app knows about
the world) and **view layer** (how it shows it to the user), with a
**data layer** in the middle that is the only place that talks to `nx_db`.

This layout is also the **prototype for future apps**. The per-entity folders
under `domain/<x>/` and `data/<x>/` are intentionally shaped to mirror
`nx_db/src/kgql/shared/<x>/`, so that promoting an entity into `nx_db` (when
a second app needs it — see `mobile/nx_db/plans/current/nx_db_app_boundary.md`)
is a file move plus an import rewrite, not a refactor.

> Assumes `nx_db` is reorganized per `mobile/nx_db/plans/current/nx_db_reorg.md`
> and exposes the sub-libraries described in
> `mobile/nx_db/plans/current/nx_db_app_boundary.md`
> (`package:nx_db/auth.dart`, `package:nx_db/kgql.dart`,
> `package:nx_db/riverpod.dart`, `package:nx_db/<entity>.dart`).

## Why this is needed

The current `lib/` layout mixes layers:

- `data/models/today_snapshot.dart` is a **view-model** (carries strings,
  `Color`s, fractions for the bar) but lives under `data/models/` next to
  KGQL-flavoured helpers.
- `screens/activity/activity_detail_models.dart` is **also a view-model**
  (`ActivityDetailArgs`) but lives next to the page — different convention
  for the same kind of object.
- `data/today_snapshot_mapper.dart` is **view-model construction** (formats
  times, computes day fractions, picks colors) — but it lives in `data/` so
  it looks like a data-mapper.
- `data/wall_clock_time.dart` and `data/model_type_bar_color.dart` are
  generic helpers (time semantics, theming) parked under `data/` because
  there was nowhere else to put them.
- `TodaySnapshot.actionModels: List<Model?>` leaks the raw `nx_db` `Model`
  type all the way to the UI, so detail/edit pages reach back into KGQL.
- `add_time_block_page.dart` and `edit_activity_page.dart` are ~80%
  duplicate code (pickers, save, validation) with no shared view-model.
- `screens/today/widgets/` exists but `screens/activity/` keeps its widgets
  inline — no consistent rule for "where do feature-local widgets live?"
- `widgets/` (top-level) and `screens/today/widgets/` overlap in intent.
- Attribute key strings like `'start_time'`, `'end_time'`, `'description'`
  are referenced from both `data/today_snapshot_mapper.dart` and the
  add/edit pages — UI code knows KGQL field names.

## The three layers

```
┌──────────────────────────────────────────────────────────────────────┐
│  features/   pages, view-models, feature widgets                      │
│              may import: domain/, package:nx_db/auth.dart,            │
│                          package:nx_db/<entity>.dart                  │
├──────────────────────────────────────────────────────────────────────┤
│  domain/     app-LOCAL entities + abstract repos (pure Dart)          │
│              promoted entities live in package:nx_db/<entity>.dart    │
├──────────────────────────────────────────────────────────────────────┤
│  data/       KGQL impls + Riverpod bindings                           │
│              may import: domain/, package:nx_db/kgql.dart,            │
│                          package:nx_db/riverpod.dart                  │
└──────────────────────────────────────────────────────────────────────┘
```

The leverage point: **`domain/` is a logical layer, not a single physical
folder**. App-local entities live in `lib/domain/<x>/`; promoted entities
live in `package:nx_db/<x>.dart`. From `features/`'s perspective the two
are interchangeable — both expose a typed entity and an abstract
repository, and both are imported the same way.

Hard rules:

- **`domain/` is pure Dart.** May import `package:nx_db/<entity>.dart`
  (promoted entities — themselves pure Dart). May NOT import
  `package:nx_db/kgql.dart`, `package:nx_db/riverpod.dart`,
  `package:flutter/...`, or `package:flutter_riverpod/...`. Could be
  lifted into a non-Flutter package and unit-tested with no dependencies.
- **`data/` depends on `domain/` + the KGQL surface of `nx_db`.** May
  import `package:nx_db/kgql.dart` (Model, SetModelRequest, repositories,
  helpers) and `package:nx_db/riverpod.dart` (graphqlClientProvider).
  All `Model.fromJson`-flavoured mapping, all attribute key strings
  (`'start_time'`), and all per-entity struct customizations live here.
  Generic struct/request/attribute plumbing is delegated to the helpers
  in `package:nx_db/kgql.dart`, never re-implemented per entity.
- **`features/` (presentation) depends on `domain/` and the
  domain-shaped surfaces of `nx_db` only.** Allowed: `domain/`,
  `package:nx_db/auth.dart`, `package:nx_db/<entity>.dart`,
  `package:nx_db/transcript.dart`. **Forbidden**:
  `package:nx_db/nx_db.dart`, `package:nx_db/kgql.dart`,
  `package:nx_db/riverpod.dart`, `package:nx_db/src/...`. View-models are
  derived from domain types.

The last rule is the leverage move. Today the detail page imports
`package:nx_db/nx_db.dart` to handle `Model`. Once you tighten the import
rule, the UI can't accidentally know about KGQL again — but it CAN
freely use promoted shared entities, because those are domain-shaped.

## Target layout

```
nx_time/
  lib/
    main.dart
    app.dart
    router.dart

    core/                                  # cross-cutting, app-wide
      theme/
        app_theme.dart                     # colors, typography
        action_color_palette.dart          # was data/model_type_bar_color.dart
      time/
        wall_clock_time.dart               # local-wall-clock semantics
        time_window.dart                   # [start, end) helper
      formatting/
        time_format.dart                   # h:mm AM split, "1h 25m"
        date_label.dart                    # "Today — Sat, Apr 18"
      layout/
        layout.dart                        # was lib/layout.dart
      widgets/                             # generic, reusable widgets
        nx_app_menu_button.dart
        nx_tab_header.dart
        task_status_segmented.dart
        task_row_tile.dart

    domain/                                # PURE Dart, no nx_db
      action/
        action.dart                        # the Action entity
        action_category.dart               # category abstraction (no modelTypeId leakage)
        action_repository.dart             # abstract: list/get/create/update/delete
      tasks/
        task.dart
        task_repository.dart
      goals/
        goal.dart
        goal_repository.dart

    data/                                  # KGQL <-> domain
      action/                              # PROMOTION-SHAPED — mirrors nx_db/src/kgql/shared/action/
        action_attr_keys.dart              # 'start_time', 'end_time', 'description'
        action_mapper.dart                 # Model -> Action, Action -> SetModelRequest
                                           # uses nx_db helpers (setKgqlCreate, attrAccessors)
        kgql_action_repository.dart        # implements ActionRepository
                                           # takes GraphQLClient + loaders, NOT Ref
        # action_kgql_struct.dart          # OPTIONAL — only if you need entity-specific
                                           # struct overrides beyond buildKgqlStructFromSchema
      tasks/                               # PROMOTION-SHAPED
        kgql_task_repository.dart
      schema/
        kgql_action_schema_repository.dart # uses get_kgql_model_type
      providers.dart                       # binds repositories to Riverpod
                                           # constructs repos from Ref, passes deps in

    features/                              # one folder per user-facing area
      today/
        today_page.dart
        today_view_model.dart              # was TodaySnapshot + mapper
        widgets/
          time_map_bar.dart
          time_map_segment.dart
          activity_row.dart
          category_legend.dart
      action_detail/
        action_detail_page.dart
        action_detail_view_model.dart      # was ActivityDetailArgs + factory
        widgets/
          time_block_bar.dart
          notes_block.dart
          linked_task_row.dart
      action_edit/
        action_edit_page.dart              # one page, modes: create | edit
        action_edit_view_model.dart        # form state, validation, save
        widgets/
          action_category_picker.dart      # was screens/activity/activity_pickers.dart
          action_datetime_picker.dart
      calendar/
        calendar_page.dart
        calendar_view_model.dart
      tasks/
        tasks_page.dart
        task_detail_page.dart
        task_create_page.dart
        task_edit_page.dart
        task_picker_page.dart
        projects_browse_page.dart
        project_drill_down_page.dart
        project_drill_deep_page.dart
        widgets/
          task_pick_widgets.dart
      goals/
        goals_page.dart
      ai/
        ai_chat_page.dart
        voice_listening_overlay.dart
      auth/
        time_login_screen.dart
      shell/
        app_shell.dart
        placeholder_tab.dart
      settings/
        action_colors_page.dart
        action_color_settings.dart
```

## Where things go and why

| Today's file                                          | New home                                                              | Why                                                                                       |
|-------------------------------------------------------|-----------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `data/today_repository.dart`                          | `data/action/kgql_action_repository.dart` + `data/providers.dart`     | Repository is **about Actions**, not "Today"; "Today" is one *use* of it.                 |
| `data/today_repository_interface.dart`                | `domain/action/action_repository.dart`                                | Lives in domain so the UI can depend on it without dragging KGQL.                         |
| `data/today_snapshot_mapper.dart`                     | `features/today/today_view_model.dart`                                | This is **view-model construction** (formatting strings, computing fractions).            |
| `data/models/today_snapshot.dart`                     | `features/today/today_view_model.dart`                                | It's a view-model bag, not a domain model.                                                |
| `data/models/today_activity.dart`                     | `features/today/today_view_model.dart`                                | Same — view layer only.                                                                   |
| `data/models/time_map_segment.dart`                   | `features/today/widgets/time_map_segment.dart`                        | Exists only for the Today bar widget.                                                     |
| `data/models/activity_category.dart`                  | Split: legend chip → `features/today/widgets/`; concept → `domain/action/action_category.dart` |
| `data/wall_clock_time.dart`                           | `core/time/wall_clock_time.dart`                                      | Generic time utility, not data.                                                           |
| `data/model_type_bar_color.dart`                      | `core/theme/action_color_palette.dart`                                | A styling concern.                                                                        |
| `data/action_category_option.dart`                    | Split: picker DTO → `features/action_edit/action_edit_view_model.dart`; concept → `domain/action/action_category.dart` |
| `data/time_kgql_schema.dart`                          | `data/action/action_kgql_struct.dart`                                 | KGQL plumbing belongs in data layer.                                                      |
| `providers/action_category_providers.dart`            | `data/providers.dart` + `features/action_edit/`                       | Data binding vs picker view-model are two concerns.                                       |
| `providers/time_providers.dart`                       | `data/providers.dart` (repo) + `features/today/today_view_model.dart` | Repository binding vs feature provider are two concerns.                                  |
| `screens/activity/activity_detail_page.dart`          | `features/action_detail/action_detail_page.dart`                      | Feature folder per concept.                                                               |
| `screens/activity/activity_detail_models.dart`        | `features/action_detail/action_detail_view_model.dart`                | Consistent naming with all other view-models.                                             |
| `screens/activity/edit_activity_page.dart`            | merge into `features/action_edit/action_edit_page.dart`               | ~80% duplicate of add page.                                                               |
| `screens/activity/add_time_block_page.dart`           | merge into `features/action_edit/action_edit_page.dart`               | One page with `mode: create | edit`.                                                      |
| `screens/activity/activity_pickers.dart`              | `features/action_edit/widgets/action_category_picker.dart` + `action_datetime_picker.dart` | One picker per file.                                                |
| `screens/today/widgets/*`                             | `features/today/widgets/*`                                            | Already in good shape, just rename `screens/` → `features/`.                              |
| `screens/shell/*`                                     | `features/shell/*`                                                    | Same.                                                                                     |
| `screens/tasks/*`                                     | `features/tasks/*`                                                    | Same.                                                                                     |
| `widgets/*` (top-level)                               | `core/widgets/*`                                                      | Generic, used across features.                                                            |

## Conventions to enforce

A handful of small rules makes the structure self-enforcing:

1. **`domain/` may import `package:nx_db/<entity>.dart` only.** Never
   `package:nx_db/kgql.dart`, `package:nx_db/riverpod.dart`,
   `package:flutter/...`, or `package:flutter_riverpod/...`. An
   `import_lint` rule catches drift. This is what guarantees the model
   layer is independent of the view layer and is promotion-eligible.
2. **`features/` may import only the domain-shaped surfaces of `nx_db`:**
   `package:nx_db/auth.dart`, `package:nx_db/<entity>.dart`,
   `package:nx_db/transcript.dart`. The fat shim
   `package:nx_db/nx_db.dart`, the raw `package:nx_db/kgql.dart`, and
   `package:nx_db/src/...` are all forbidden in `features/`.
3. **One feature folder per top-level user concept**, with the same shape
   inside: `xxx_page.dart`, `xxx_view_model.dart`, and a local `widgets/`
   folder. Anything used by two features moves to `core/widgets/`.
4. **View models are *derived state*, not state itself.** A
   `TodayViewModel` is a `Provider` that watches the action repository for
   today's window and produces strings/colors the page needs. The page
   never formats or computes anything itself.
5. **Naming**: snake_case files. Page is `xxx_page.dart`, view-model is
   `xxx_view_model.dart`, repository is `xxx_repository.dart`, provider
   bag is `providers.dart` (one per layer). Per-entity folders under
   `domain/<x>/` and `data/<x>/` use **the same file names** as
   `nx_db/src/kgql/shared/<x>/` so promotion is `git mv`.
6. **Attribute key strings (`'start_time'`, `'description'`, …) live only
   in `data/<x>/<x>_attr_keys.dart`.** When `<x>` promotes, the file
   moves to `nx_db/src/kgql/shared/<x>/<x>_attr_keys.dart` — same name,
   one home.
7. **The repository returns `domain` types only.** No leaking `Model` into
   the UI. Replace `TodaySnapshot.actionModels: List<Model?>` with a
   `domain.Action` list and let the data layer hand back fully-formed
   domain entities.
8. **KGQL repository classes do NOT hold a Riverpod `Ref`.** They take
   their concrete dependencies (`GraphQLClient`, schema loader, etc.) in
   their constructor. Riverpod resolution lives in `data/providers.dart`,
   which builds the repo from `Ref`. This makes the class promotable to
   `nx_db/src/kgql/shared/<x>/` unchanged — `nx_db` is Riverpod-free at
   the repository level.
9. **Generic KGQL plumbing comes from `package:nx_db/kgql.dart` helpers,
   not hand-rolled per entity.** Specifically:
   - Build the GraphQL `struct` with `buildKgqlStructFromSchema(schema)`.
   - Build write requests with `setKgqlCreate / setKgqlUpdate /
     setKgqlDelete`.
   - Read attributes off `Model` via the `attrString` / `attrInt` /
     `attrDateTime` extensions.

   Per-entity files only contain the **entity-specific** parts: which
   attr keys to read, which struct overrides (if any), how to map fields
   into the domain entity. Boilerplate stays in `nx_db`.
10. **Mappers are pure functions.** `actionFromModel(Model) -> Action` and
    `setRequestFor*(Action) -> SetModelRequest` take no `Ref`, no
    `BuildContext`, no providers. This is what lets them migrate to
    `nx_db` as-is.

## Concrete data flow under the new structure

A single tap on a Today row:

1. **User taps a row on the Today page.**
2. `today_page.dart` reads `todayViewModelProvider` → gets a
   `TodayViewModel { actions: List<TodayActionRow> }`. `TodayActionRow`
   carries display strings + the **domain** `Action` (not a KGQL `Model`).
3. Tap → push `ActionDetailPage(actionId: row.action.id)`.
4. `action_detail_view_model.dart` exposes
   `actionDetailProvider.family<Action, int>` which calls
   `ref.read(actionRepositoryProvider).getById(id)`.
5. The page receives a domain `Action`, then computes its own
   `ActionDetailViewModel` (split times, pill colors, notes block visibility).
6. **Edit** pushes `ActionEditPage(initial: action)`, which on save calls
   `actionRepository.upsert(updatedAction)`.
7. `data/action/kgql_action_repository.dart` is the **only** place that
   knows that maps to `SetModelRequest` and KGQL attribute keys.

The UI never says the words "Model", "attributes", or "set_kgql_models".

## What this gets you in practice

- **Swappable backends.** A fake/in-memory `ActionRepository` for
  screenshots is just another `domain.ActionRepository` impl.
- **Refactor blast radius is small.** Changing how KGQL filters work
  touches `data/action/`. Changing how the Today bar renders touches
  `features/today/`. Today both live in `data/` and edits cross-pollinate.
- **Onboarding.** A new dev opens `lib/`, sees
  `core / domain / data / features`, and immediately knows where to look.
- **Cross-app reuse is mechanical.** Because per-entity folders mirror
  the `nx_db` shared-entity shape, promoting an entity to `nx_db` for a
  second app is a file move, not a rewrite (see next section).

## Promotion to `nx_db`

An entity in `lib/domain/<x>/` + `lib/data/<x>/` is **app-local** until a
second app needs it. To make promotion mechanical, the prototype follows
three rules:

1. **File names mirror the `nx_db` target.** `<x>.dart`,
   `<x>_repository.dart` (abstract), `kgql_<x>_repository.dart`,
   `<x>_attr_keys.dart`, `<x>_mapper.dart` — same names as
   `nx_db/src/kgql/shared/<x>/`.
2. **Repositories never read `Ref`.** `kgql_<x>_repository.dart` takes
   `GraphQLClient` (and any other concrete deps) in its constructor.
   Riverpod's `Ref` is used only inside `data/providers.dart` to *resolve*
   those deps. Once promoted, the class compiles unchanged in `nx_db`.
3. **Riverpod bindings stay in the app.** `data/providers.dart` keeps
   `actionRepositoryProvider = Provider((ref) => KgqlActionRepository(...))`
   even after the class moves into `nx_db`. The provider is the seam;
   don't promote it unless every app would write the same line.

When `Action` promotes:

- `lib/domain/action/{action.dart, action_repository.dart}` → **deleted**;
  imports rewritten to `package:nx_db/action.dart`.
- `lib/data/action/{kgql_action_repository.dart, action_attr_keys.dart,
  action_mapper.dart}` → **deleted**; imports rewritten.
- `lib/data/providers.dart` → unchanged in shape; just imports
  `KgqlActionRepository` from `package:nx_db/action.dart`.
- `features/action_*` and any view-model files: **untouched**.

The per-entity folders under `domain/` and `data/` are therefore
**transient homes** — they exist while the entity is app-local and
disappear when it promotes.

### Core utilities promotion table

Not everything in `core/` is promotion-eligible. Some utilities encode
KGQL semantics (and so belong in `nx_db` if shared); others are display
concerns (and stay app-local even when reused, because reuse means
copying the convention, not the file).

| File                                  | Promotion target if shared                            | Why                                                                  |
|---------------------------------------|-------------------------------------------------------|----------------------------------------------------------------------|
| `core/time/wall_clock_time.dart`      | `nx_db/src/kgql/helpers/wall_clock.dart`              | KGQL stores `start_time`/`end_time` as wall-clock ISO; semantics belong with KGQL. |
| `core/time/time_window.dart`          | Stay in app                                           | Generic `[start, end)` Dart utility; no KGQL coupling.               |
| `core/formatting/time_format.dart`    | Stay in app                                           | Display concern (locale, "1h 25m" style choice).                     |
| `core/formatting/date_label.dart`     | Stay in app                                           | Display concern.                                                     |
| `core/theme/*`                        | Stay in app                                           | Each app picks its own colors/typography.                            |
| `core/widgets/*`                      | Stay in app                                           | Generic widgets are not KGQL-shaped; if truly cross-app, extract to a `nx_widgets` package, not `nx_db`. |

## Incremental migration order

If a big-bang rewrite is too risky, this order delivers value at each step
without breaking the running app. Steps 1–7 are the original layering
moves; steps 8–10 prepare the app to feed `nx_db` once the boundary
plan lands.

1. **Create `domain/action/`** with `Action`, `ActionCategory`,
   `ActionRepository` interface. Wrap existing code by having the data
   layer return domain types from a *new* repository method, used by
   *one* screen first (e.g. detail page).
2. **Move helpers**: `wall_clock_time.dart` → `core/time/`,
   `model_type_bar_color.dart` → `core/theme/`. Pure rename + import
   update; safest first move.
3. **Kill `data/models/`.** Move `today_snapshot.dart`,
   `today_activity.dart`, `today_snapshot_mapper.dart` into
   `features/today/today_view_model.dart`. This single move clears up
   the worst confusion.
4. **Merge `add_time_block_page.dart` and `edit_activity_page.dart`**
   into one `features/action_edit/action_edit_page.dart` with a mode
   flag. Forces extracting shared `_pickCategory` / `_pickStart` /
   `_save` logic into a real `ActionEditViewModel`.
5. **Drop `Model` from `TodaySnapshot.actionModels`.** Replace with
   `List<Action>`. Once it compiles, the UI no longer depends on `nx_db`
   for `Action` rows.
6. **Add an `import_lint` rule** banning `package:nx_db/nx_db.dart`,
   `package:nx_db/kgql.dart`, `package:nx_db/riverpod.dart`, and
   `package:nx_db/src/...` from `lib/features/**`; banning Flutter and
   Riverpod from `lib/domain/**`. Without an automated check, the
   layering will rot back within weeks.
7. **Rename `screens/` → `features/`** and move feature-local widgets
   into per-feature `widgets/` folders. Move top-level `widgets/` into
   `core/widgets/`.
8. **Refactor `KgqlActionRepository` to be `Ref`-free.** Take
   `GraphQLClient` and a `Future<ModelType> Function() schemaLoader` in
   the constructor. Construct it from `Ref` inside
   `data/providers.dart`. After this step the class is promotion-ready
   without touching `nx_db`.
9. **Adopt `nx_db` sub-libraries.** Replace `package:nx_db/nx_db.dart`
   imports across the app: `features/` and `domain/` use
   `package:nx_db/auth.dart` and `package:nx_db/<entity>.dart`; `data/`
   uses `package:nx_db/kgql.dart` and `package:nx_db/riverpod.dart`.
   Delete `data/auth_bridge.dart` (if it exists) — it's now redundant.
10. **Adopt the `nx_db/kgql/helpers/` API in `data/<x>/`.** Replace
    `buildActionActivityStruct` with `buildKgqlStructFromSchema(schema)`.
    Replace hand-rolled `SetModelRequest` builders with `setKgqlCreate /
    setKgqlUpdate / setKgqlDelete`. Replace
    `if (raw is String) … else raw.toString()` reads with
    `model.attrString(...)` / `model.attrDateTime(...)`. After this step,
    per-entity mapper files shrink to the entity-specific bits only.

After steps 8–10 the app is "promotion-shaped": when a second app needs
`Action`, the actual move into `nx_db/src/kgql/shared/action/` is a
`git mv` and an import rewrite — no logic changes, no view-model
churn.
