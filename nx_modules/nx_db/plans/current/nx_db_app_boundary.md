# `nx_db` multi-app boundary plan

Goal: tighten the `nx_db` ↔ app seam so that (a) future apps can adopt
`nx_db` without forking it, and (b) chunks that prove "shared" inside one
app can be **moved** into `nx_db` instead of copy-pasted into the next app.

> Assumes the structural reorg in `nx_db_reorg.md` has landed (or lands
> alongside this). This plan is about the **public boundary** and the
> **shared-entity tier**, not the internal folder layout.

## Why this is needed

Today the internal layering of `nx_db` (per `nx_db_reorg.md`) is right —
`core/` plumbing, `kgql/` ORM, `auth/`, `transcript/` feature module — but
the **boundary** between `nx_db` and consuming apps has rough edges that
will become painful as soon as a second app appears.

Concrete problems observable in the current `nx_time` consumer:

- `nx_db.dart` exports **everything** under `src/`: documents, JSON
  helpers (`payload_unwrap`, `json_coercion`), repository functions, raw
  `.graphql.dart` strings, and `login_page.dart`. There is no real
  "curated public surface" — it's a kitchen sink. Once an app depends on
  `payload_unwrap`, refactoring it breaks downstream.
- `login_page.dart` is still inside `nx_db` (the existing reorg flagged
  this). It forces every consumer to depend on Flutter Material, blocking
  reuse from CLIs / tests / server-side Dart.
- Riverpod is baked into the public API. `fetchKgqlModels` is pure, but
  `modelsByTypeProvider` and friends are exported alongside it. Apps that
  don't use Riverpod can't adopt `nx_db` without dragging it in.
- `nx_time/lib/data/action/action_mapper.dart` reaches into `src/`
  directly to dodge a name collision:
  ```dart
  import 'package:nx_db/nx_db.dart' hide ModelAttribute;
  import 'package:nx_db/src/kgql/requests/set_model_request.dart' show ModelAttribute;
  ```
  An app should never need to bypass the public API.
- `nx_time/lib/data/auth_bridge.dart` exists *only* to re-export a chosen
  subset of `nx_db` so that `features/` doesn't import `nx_db` directly.
  This is the right idea, but each app will invent its own bridge with a
  different subset — that should be `nx_db`'s job, not the app's.
- There is **no tier in `nx_db` for "typed entity + abstract repository
  shared by 2+ apps."** Today there's the generic ORM (`kgql/`) and one
  vertical feature (`transcript/`). When `Action` ships in app #2, there
  is no obvious home for it inside `nx_db`.
- Generic helpers are duplicated per entity in apps. Examples worth
  promoting:
  - `nx_time/data/action/action_kgql_struct.dart::buildActionActivityStruct`
    — generic over a `ModelType`, builds a struct with attributes,
    relations, embedded `model_type`. Every entity in every app will need
    the same shape.
  - `nx_time/data/action/action_mapper.dart::setModelRequestFor{Create,Update,Delete}`
    — same shape repeats per entity.
  - The `if (raw is String) … else raw.toString()` dance in
    `notesDescriptionFromModel` — every typed read off `Model.attributes`
    redoes this.

## Target boundary

Two structural changes to `nx_db`, plus a small set of helpers that today
live in apps:

```
nx_db/
  lib/
    nx_db.dart            # everything-shim (kept for ergonomics)
    auth.dart             # NEW — public sub-surface
    kgql.dart             # NEW — public sub-surface (pure, Riverpod-free)
    riverpod.dart         # NEW — opt-in Riverpod surface
    transcript.dart       # NEW — feature surface

    src/
      core/
      auth/
      kgql/
        documents/        # internal — no longer publicly exported
        models/
        requests/
        repositories/
        providers/
        helpers/          # NEW — generic struct & request helpers
          struct_builder.dart
          set_request_helpers.dart
          attr_accessors.dart
        shared/           # NEW — typed entities promoted from apps
          # (empty at first; populated as features migrate)
      transcript/
```

The two structural moves:

1. **Sub-libraries instead of a single `nx_db.dart`.** Apps choose their
   dependency surface. `nx_db.dart` stays as an "import everything" shim
   so existing call sites don't break.
2. **`kgql/shared/`** is the new home for entities used by 2+ apps. Same
   shape every time:
   ```
   kgql/shared/<entity>/
     <entity>.dart                 # typed entity, pure Dart
     <entity>_repository.dart      # abstract interface
     kgql_<entity>_repository.dart # default KGQL impl
     <entity>_attr_keys.dart       # 'start_time', etc.
     <entity>_mapper.dart          # Model <-> entity, Set request builders
   ```
   This is the **promotion target**. Migrating `Action` from `nx_time`
   becomes "move 5 files, fix imports."

## Public surface — sub-libraries

Each top-level `lib/*.dart` is a curated, stable export list. Internals
under `src/` are off-limits to consumers.

### `package:nx_db/auth.dart`

```dart
export 'src/auth/user.dart';
export 'src/auth/auth_controller.dart';
export 'src/auth/auth_providers.dart';
export 'src/auth/backend_ping.dart';
export 'src/core/config/backend_presets.dart';
export 'src/core/config/cf_access.dart';
export 'src/core/config/graphql_http_config.dart';
```

No KGQL, no Material. Replaces today's `nx_time/lib/data/auth_bridge.dart`.

### `package:nx_db/kgql.dart` — pure, Riverpod-free

```dart
export 'src/kgql/models/model.dart';
export 'src/kgql/models/model_type.dart';
export 'src/kgql/models/attribute.dart';
export 'src/kgql/models/relation.dart';
export 'src/kgql/models/tag_node.dart';
export 'src/kgql/models/tag_system.dart';
export 'src/kgql/requests/set_model_request.dart';
export 'src/kgql/requests/set_model_type_request.dart';
export 'src/kgql/repositories/models_repository.dart';
export 'src/kgql/repositories/model_types_repository.dart';
export 'src/kgql/repositories/aggregate_repository.dart';
export 'src/kgql/helpers/struct_builder.dart';
export 'src/kgql/helpers/set_request_helpers.dart';
export 'src/kgql/helpers/attr_accessors.dart';
export 'src/core/client/graphql_client.dart';
```

Apps that don't use Riverpod can adopt `nx_db` via this surface alone.

### `package:nx_db/riverpod.dart`

```dart
export 'src/core/client/graphql_client_provider.dart';
export 'src/kgql/providers/models_providers.dart';
export 'src/kgql/providers/model_types_providers.dart';
export 'src/kgql/providers/relation_picker_providers.dart';
```

### `package:nx_db/transcript.dart`

```dart
export 'src/transcript/transcript.dart';
export 'src/transcript/transcript_repository.dart';
export 'src/transcript/transcript_providers.dart';
```

### What goes **out** of the public surface

These were exported in `nx_db.dart` and **must not** be in the new
sub-libraries:

- `src/kgql/documents/*.graphql.dart` — internal. If a test needs them,
  add a separate `package:nx_db/internal.dart` escape hatch with a
  `// not part of public API; may break in any release.` comment at the
  top.
- `src/core/json/json_coercion.dart`, `src/core/json/payload_unwrap.dart`
  — internal. Use them inside `kgql/repositories/`, never re-export.
- `src/auth/login_page.dart` — leaves the package entirely (see below).

`nx_db.dart` keeps the same export list **minus** the four bullets above,
so existing apps keep compiling but new apps are nudged toward the
sub-libraries.

## What leaves `nx_db` entirely

- **`src/auth/login_page.dart`.** Already flagged in `nx_db_reorg.md` as
  "does not belong." Move to the consuming app (`nx_time/lib/features/auth/`
  already exists), or to a small `nx_auth_ui` package if more than one app
  needs the same screen. The auth controller / providers stay in
  `nx_db/auth/` — only the Material widget leaves.

## New: `kgql/helpers/` — generic plumbing apps shouldn't reinvent

These three files capture patterns currently duplicated per entity in apps.

### `struct_builder.dart`

Generalizes `nx_time/lib/data/action/action_kgql_struct.dart`:

```dart
Map<String, dynamic> buildKgqlStructFromSchema(
  ModelType schema, {
  bool includeRelationsNode = true,
  bool includeModelTypeMeta = true,
  Iterable<String> extraTopLevel = const ['id', 'name', 'description',
                                          'created_at', 'model_type_id'],
});
```

Walks `schema.attributes` and `schema.relations`, returns the same `struct`
map shape every entity needs. App-side use becomes one line per entity.

### `set_request_helpers.dart`

Generalizes the create/update/delete builders in `action_mapper.dart`:

```dart
SetModelRequest setKgqlCreate({
  required String modelType,
  required String name,
  String? description,
  required List<ModelAttribute> attributes,
});

SetModelRequest setKgqlUpdate({
  required int id,
  String? modelType,
  required String name,
  String? description,
  required List<ModelAttribute> attributes,
});

SetModelRequest setKgqlDelete(int id);
```

Per-entity mappers shrink to "build the attributes list, hand it to the
helper."

### `attr_accessors.dart`

Replaces the `if (raw is String) … else raw.toString()` dance with typed
accessors:

```dart
extension ModelAttrReads on Model {
  String?   attrString(String key);
  int?      attrInt(String key);
  double?   attrDouble(String key);
  bool?     attrBool(String key);
  DateTime? attrDateTime(String key); // ISO-8601, returns local wall-clock
}
```

Centralizes the parsing rules; per-entity mappers stop hand-rolling them.
**Also fixes the `ModelAttribute` collision** by giving callers a typed
read path that doesn't need to import the request DTO at all.

## New: `kgql/shared/` — promotion target for app entities

Empty at first. The convention is the **only** thing that ships with this
plan. When an entity (e.g. `Action`) needs to be reused, it migrates from
`<app>/lib/data/<entity>/` and `<app>/lib/domain/<entity>/` into:

```
nx_db/lib/src/kgql/shared/<entity>/
  <entity>.dart                 # was <app>/domain/<entity>/<entity>.dart
  <entity>_repository.dart      # was <app>/domain/<entity>/<entity>_repository.dart
  <entity>_attr_keys.dart       # was <app>/data/<entity>/<entity>_attr_keys.dart
  <entity>_mapper.dart          # was <app>/data/<entity>/<entity>_mapper.dart
  kgql_<entity>_repository.dart # was <app>/data/<entity>/kgql_<entity>_repository.dart
```

…and is exposed as a sub-library:

```
nx_db/lib/<entity>.dart
  export 'src/kgql/shared/<entity>/<entity>.dart';
  export 'src/kgql/shared/<entity>/<entity>_repository.dart';
  export 'src/kgql/shared/<entity>/kgql_<entity>_repository.dart';
```

App diff per migration: delete 5 files, change imports from
`'../../domain/<entity>/<entity>.dart'` to `'package:nx_db/<entity>.dart'`,
keep all view-models and pages untouched.

> The repository in `kgql/shared/` should take a `GraphQLClient`, not a
> Riverpod `Ref`, so a non-Riverpod app can still use it. The Riverpod
> binding (`actionRepositoryProvider = …`) stays in the **app**, not in
> `nx_db`. If two apps end up writing the same provider literally, *then*
> promote the provider to `nx_db/riverpod.dart` — but not by default.

## Conventions to enforce

A handful of rules that make the boundary self-policing:

1. **Apps import from sub-libraries, not `package:nx_db/nx_db.dart`.**
   The fat shim stays for backward compatibility, but new code uses
   `auth.dart`, `kgql.dart`, `riverpod.dart`, or a shared-entity surface.
   An `import_lint` rule enforces this in `lib/features/**` and
   `lib/domain/**`.
2. **`domain/` in apps may import only `package:nx_db/<entity>.dart`** —
   never `kgql.dart` directly. The shared-entity surface is the
   *domain-shaped* part of `nx_db`. KGQL plumbing stays in app `data/`.
3. **No imports from `package:nx_db/src/...`** anywhere outside `nx_db`
   itself. The current `hide ModelAttribute` workaround in
   `action_mapper.dart` is the canonical anti-example.
4. **`kgql/repositories/` and `kgql/shared/*/kgql_*_repository.dart` take
   `GraphQLClient`, never `Ref`.** Riverpod glue lives in `providers/`.
5. **`kgql/helpers/` is pure**: no Riverpod, no Flutter, no app concepts.
   It only depends on `kgql/models/` and `kgql/requests/`.
6. **No Flutter Material in `nx_db`.** `login_page.dart` is the last
   offender; once it's out, an `import_lint` rule bans
   `package:flutter/material.dart` from `nx_db/lib/**`.
7. **Promotion is two-app-driven.** A file moves to `kgql/shared/` only
   after a second app needs it. Don't pre-promote on speculation.

## Promotion recipe (when does code move into `nx_db`?)

The intended lifecycle of a chunk of code:

| Stage | Lives in | Trigger to move on |
|-------|----------|--------------------|
| 1. New | `<app>/lib/features/<x>/` (UI) and `<app>/lib/domain/`+`data/` | Used by one app, one screen |
| 2. App-shared | Same, but referenced by multiple features in the app | Still only one app needs it |
| 3. Cross-app | `nx_db/lib/src/kgql/shared/<x>/` + `nx_db/lib/<x>.dart` | A second app wants it |
| 4. Generic | `nx_db/lib/src/kgql/helpers/` | Pattern is **schema-shaped**, not entity-shaped (e.g. struct builder) |

Three-step recipe for stage 2 → stage 3:

1. **Identify the unit.** Entity class + abstract repo + KGQL impl +
   attr-keys + mapper. Move them as a set; never split.
2. **Move the files** into `nx_db/src/kgql/shared/<entity>/`. Add a
   one-line `nx_db/lib/<entity>.dart` re-export.
3. **In the source app:** delete the originals, change imports to
   `package:nx_db/<entity>.dart`. Keep the **Riverpod provider binding**
   (`actionRepositoryProvider = Provider((ref) => KgqlActionRepository(...))`)
   in the app's `data/providers.dart`. View-models and pages stay
   untouched because they always saw the abstract `ActionRepository`.

If step 3 requires touching any view-model or page, the layering in the
source app was wrong — fix that first, then promote.

## Mapping from today → target boundary

| Today                                                                 | Target                                                  |
|----------------------------------------------------------------------|---------------------------------------------------------|
| `nx_db.dart` exports everything                                       | `nx_db.dart` becomes shim; sub-libraries are the API    |
| `nx_db.dart` exports `src/kgql/documents/*.graphql.dart`              | Internal; not re-exported (use `internal.dart` if needed) |
| `nx_db.dart` exports `src/core/json/*`                                | Internal; not re-exported                               |
| `nx_db.dart` exports `src/auth/login_page.dart`                       | File moves out of `nx_db` entirely                      |
| `nx_time/lib/data/auth_bridge.dart`                                   | Deleted; features import `package:nx_db/auth.dart`      |
| `nx_time/lib/data/action/action_kgql_struct.dart`                     | Generalized into `nx_db/src/kgql/helpers/struct_builder.dart` |
| `nx_time/lib/data/action/action_mapper.dart` (Set request builders)   | Generalized into `nx_db/src/kgql/helpers/set_request_helpers.dart` |
| `nx_time/lib/data/action/action_mapper.dart` (`if (raw is String)` …) | Generalized into `nx_db/src/kgql/helpers/attr_accessors.dart` |
| `import 'package:nx_db/src/kgql/requests/set_model_request.dart'`     | Removed — accessors don't need it; if needed, rename `ModelAttribute` to `RequestAttribute` |
| `nx_time/lib/data/action/*` + `nx_time/lib/domain/action/*` (when app #2 needs Action) | Promoted to `nx_db/src/kgql/shared/action/` + `nx_db/lib/action.dart` |

## Incremental migration order

Each step is independently shippable and keeps the app green.

1. **Add `auth.dart` sub-library** in `nx_db`. Re-exports the same symbols
   `nx_time/lib/data/auth_bridge.dart` chose. Switch `auth_bridge.dart`
   to re-export `package:nx_db/auth.dart` instead of cherry-picking from
   `nx_db.dart`. (Single-file, low risk; proves the pattern.)
2. **Add `kgql.dart` and `riverpod.dart` sub-libraries.** No call-site
   changes yet — `nx_db.dart` still exports the same surface.
3. **Add `kgql/helpers/attr_accessors.dart`.** Refactor
   `notesDescriptionFromModel` and the wall-clock attribute reads in
   `action_mapper.dart` to use the new accessors. Removes the
   `ModelAttribute` collision and the `import 'src/...'` reach-through.
4. **Add `kgql/helpers/set_request_helpers.dart`.** Rewrite
   `setModelRequestFor{Create,Update,Delete}` in `action_mapper.dart` as
   thin wrappers around the helpers.
5. **Add `kgql/helpers/struct_builder.dart`.** Replace
   `buildActionActivityStruct` with a one-line call to
   `buildKgqlStructFromSchema(schema)`.
6. **Move `login_page.dart` out of `nx_db`** into
   `nx_time/lib/features/auth/`. Drop the export from `nx_db.dart`. Add an
   `import_lint` rule banning `package:flutter/material.dart` from
   `nx_db/lib/**`.
7. **Stop exporting `documents/` and `core/json/` from `nx_db.dart`.**
   Add `nx_db/lib/internal.dart` if any test imports them. Update tests.
8. **Add `kgql/shared/` (empty) + the promotion recipe doc.** Sets the
   convention before app #2 arrives.
9. **Add an `import_lint` rule** banning `package:nx_db/src/...` outside
   `nx_db`, and banning `package:nx_db/nx_db.dart` from new code in
   `nx_time/lib/features/**` (sub-libraries only).
10. **First real promotion** when app #2 needs `Action`: move
    `nx_time/lib/{domain,data}/action/*` → `nx_db/src/kgql/shared/action/`,
    add `nx_db/lib/action.dart`, switch `nx_time` imports.

Steps 1–7 are pure cleanup and pay for themselves inside `nx_time` alone.
Step 8 sets the convention. Step 10 is the payoff that justifies the
whole plan.

## What this gets you in practice

- **A second app costs less.** It depends on `package:nx_db/auth.dart`
  and `package:nx_db/kgql.dart`, gets the helpers for free, and writes
  only its own view-models, pages, and feature-specific entities.
- **Shared entities migrate by file move.** `Action` (or any future
  entity) moves into `nx_db` without touching any view-model or page in
  the source app, because the app already only knew the abstract
  repository.
- **Non-Flutter / non-Riverpod consumers become possible.** A CLI, a
  test harness, or a server-side script can use `package:nx_db/kgql.dart`
  alone. Today they can't — `login_page.dart` and the always-Riverpod
  exports block them.
- **Refactoring `nx_db` internals stops being a breaking change.**
  Documents, JSON helpers, and `src/...` paths are no longer part of any
  app's import graph.
