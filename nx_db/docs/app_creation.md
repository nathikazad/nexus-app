# Creating a new Nexus app

This guide is for "I'm starting a new Flutter app on top of `nx_db`."
Follow it and you'll end up with the same architecture as `nx_time`,
which is the canonical model prototype. Read this **with the
[`nx_db/docs/structure.md`](./structure.md) doc and the
[`nx_time/docs/current_plan/nx_time_reorg.md`](../../nx_time/docs/current_plan/nx_time_reorg.md)
doc** open in adjacent tabs — those are the spec, this is the rollout
recipe.

The architecture has two non-negotiables:

1. **Layered code:** `core/` ⟶ `domain/` ⟶ `data/` ⟶ `features/`. Lower
   layers never import upper ones, and `domain/` stays Flutter-free,
   Riverpod-free, and `nx_db`-free.
2. **Curated `nx_db` imports:** the app picks the smallest
   `package:nx_db/<x>.dart` sub-library that fits, and `features/` only
   ever imports `package:nx_db/auth.dart`.

If you keep those two rules, everything else in this guide drops out
mechanically.

---

## 1. Bootstrap the Flutter package

From `mobile/`:

```bash
flutter create --template=app --org com.nexus --platforms ios,android,web nx_<yourapp>
cd nx_<yourapp>
```

Replace the generated `pubspec.yaml` with this template (cribbed from
`nx_time/pubspec.yaml`):

```yaml
name: nx_<yourapp>
description: <one-line app description>
publish_to: "none"
version: 0.1.0+1

environment:
  sdk: ^3.9.2

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.2.0
  graphql_flutter: ^5.1.2
  go_router: ^17.0.1
  intl: ^0.20.2
  google_fonts: ^8.0.2
  nx_db:
    path: ../nx_db

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  mocktail: ^1.0.4
  shared_preferences: ^2.2.2

flutter:
  uses-material-design: true
```

Notes:

- `flutter_riverpod`, `graphql_flutter`, `shared_preferences`, and
  `nx_db`'s GraphQL/auth machinery all line up on those versions. Don't
  drift from them or you'll get duplicate dependency resolutions.
- `nx_db` is consumed by **path** during local development; the package
  is not published.
- `mocktail` + `shared_preferences` in `dev_dependencies` mirrors the
  test patterns described in section 8 below.

Delete the generated `lib/main.dart`, `test/widget_test.dart`, and the
`README.md` Flutter put in. You'll write your own.

---

## 2. Create the folder skeleton

The whole app fits inside four top-level folders under `lib/`. Create
them empty up front so the layer boundaries are visible from day one:

```
lib/
  main.dart                # entry — ProviderScope + your root widget
  app.dart                 # MaterialApp.router + theme + routerProvider
  router.dart              # GoRouter, redirect on authProvider

  core/                    # generic, Flutter-only, app-agnostic
    theme/
    layout/
    formatting/
    time/                  # (or whatever utility namespace you need)
    widgets/               # generic widgets (no business logic, no auth)

  domain/                  # PURE DART — no flutter, no nx_db, no riverpod
    <entity>/
      <entity>.dart                # the typed entity class
      <entity>_repository.dart     # abstract Repository interface
    schema/                        # (if you have schema-shaped types)

  data/                    # bridges domain ⇄ nx_db (KGQL + Riverpod live HERE)
    providers.dart                 # repository providers, derived providers
    <entity>/
      kgql_<entity>_repository.dart    # implements domain repository over GraphQLClient
      <entity>_mapper.dart             # Model ⇄ <entity>; Set<Entity> ⇄ SetModelRequest
      <entity>_attr_keys.dart          # const String keys for KGQL attributes
      <entity>_schema_provider.dart    # if you cache a ModelType for this entity
      <entity>_subtypes_provider.dart  # if you fan out by subtype
    schema/
      kgql_<entity>_schema_repository.dart   # if a schema needs its own repo

  features/                # SCREENS + view-models — Riverpod, Material, Navigator
    <feature>/
      <feature>_page.dart
      <feature>_view_model.dart
      <feature>_providers.dart       # Riverpod providers specific to this feature
      widgets/                       # widgets used only by this feature
    auth/
      <yourapp>_login_screen.dart    # YOUR app's login UI (don't ship from nx_db)
    shell/
      app_shell.dart                 # bottom nav / drawer / scaffold for authed routes
```

> The names `core`, `domain`, `data`, `features` are load-bearing — the
> layering tests in section 8 grep for them. Don't rename them.

---

## 3. Wire `main.dart` and `app.dart` (the Riverpod sequence)

The exact sequence — `ProviderScope` ⟶ `MaterialApp.router` ⟶
`routerProvider` ⟶ `authProvider` — is what makes auth + Riverpod work
together. Follow it verbatim; deviating breaks the redirect logic on
sign-in/out.

### `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_<yourapp>/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: NexusYourAppApp()));
}
```

`ProviderScope` is the **only** place a `ProviderScope` is created. All
state flows through it.

### `lib/app.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_<yourapp>/core/theme/app_theme.dart';
import 'package:nx_<yourapp>/router.dart';

class NexusYourAppApp extends ConsumerWidget {
  const NexusYourAppApp({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider(initialTabIndex));
    return MaterialApp.router(
      title: 'Nexus YourApp',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
```

Two things to copy literally:

- The root widget is a `ConsumerWidget` so it can `ref.watch` the
  router. If you use a `StatelessWidget` here you'll never get a rebuild
  when the user logs in/out.
- The `initialTabIndex` constructor parameter is the hook that
  screenshot-driver integration tests use to land on a specific tab
  without manual taps. Keep it even if your app has only one tab today.

---

## 4. Auth + routing (`lib/router.dart`)

Routing is a `Provider.family<GoRouter, int>` that **listens to
`authProvider` and forces the router to refresh on every auth state
change**. This is the entire mechanism by which sign-in pushes the user
into the app and sign-out kicks them out.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_<yourapp>/features/auth/<yourapp>_login_screen.dart';
import 'package:nx_<yourapp>/features/shell/app_shell.dart';

final routerProvider = Provider.family<GoRouter, int>((ref, initialTabIndex) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) => refresh.value++);

  final initial = initialTabIndex == 0
      ? '/home'
      : '/home?tab=$initialTabIndex';

  return GoRouter(
    refreshListenable: refresh,
    initialLocation: initial,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      if (auth.isLoading) return null;          // wait for restore-session ping
      final user = auth.value;
      final path = state.uri.path;
      if (user == null && path != '/login') return '/login';
      if (user != null && path == '/login') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const YourAppLoginScreen()),
      GoRoute(
        path: '/home',
        builder: (_, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
          return AppShell(initialTabIndex: tab);
        },
      ),
      // …app-specific routes here
    ],
  );
});
```

### What this gives you for free

`authProvider` (from `nx_db/auth.dart`) is an
`AsyncNotifierProvider<AuthController, User?>`. When the app starts,
its `build()` reads `SharedPreferences`, optionally pings the GraphQL
backend to validate the session, and yields a `User?`. Three states:

| `authProvider` state | `redirect` returns | Meaning |
|---|---|---|
| `AsyncLoading` | `null` | Don't redirect — show whatever route is currently mounted (typically the splash route, see "Loading screen" below). |
| `AsyncData(null)` | `/login` if not already there | Unauthenticated. |
| `AsyncData(User)` | `/home` if currently on `/login` | Authenticated. |
| `AsyncError` | `/login` if not already there (handle in `redirect`) | Treat like unauthenticated, show error on the login screen. |

### The login screen lives in YOUR app

`nx_db` deliberately does **not** ship a `LoginPage`. Each app builds
its own under `features/auth/<yourapp>_login_screen.dart` so it
matches the app's theme, fonts, and copy. The login screen's only
contract is to call:

```dart
final errorMessage = await ref
    .read(authProvider.notifier)
    .login(userIdController.text.trim(), selectedPreset);
```

`login()` returns `null` on success or an error message string. On
success, the auth state flips, the `routerProvider` listener fires, and
GoRouter automatically redirects to `/home`. **Don't** push routes
manually from the login button. Let the redirect do it.

The backend selector dropdown should iterate `BackendPreset.values` and
default to `BackendPreset.defaultPreset` — both are exported from
`package:nx_db/auth.dart`. See `nx_time/lib/features/auth/time_login_screen.dart`
for a complete worked example.

### Loading screen (optional but recommended)

If `authProvider` is in `AsyncLoading` (session restore + ping), `redirect`
returns `null` and GoRouter shows `initialLocation`. If your initial
route is `/home`, the user briefly sees an empty shell. To avoid that,
either:

- Wrap `AppShell`'s body in a `ref.watch(authProvider).when(loading: …)`
  to render a spinner; or
- Add a `/splash` route as `initialLocation` and have `redirect` push to
  `/login` or `/home` once `auth.value` resolves.

`nx_time` takes the first approach because the only authed-mode loading
state is `todaySnapshotProvider`, which the shell already gates on.

### Sign-out

```dart
ref.read(authProvider.notifier).logout();
```

That's it. The router will redirect to `/login` automatically.

---

## 5. The data flow — KGQL through `nx_db`

The data layer is where `nx_db/kgql.dart` and `nx_db/riverpod.dart` get
imported. Keep this code **inside `lib/data/`**. Nothing in
`lib/features/` should import either of those sub-libraries.

### Repository pattern (per entity)

For an entity called `<E>`:

1. **`lib/domain/<e>/<e>.dart`** — the typed Dart class. Pure Dart only.
   No `Model`, no `Map<String, dynamic>`.
2. **`lib/domain/<e>/<e>_repository.dart`** — an abstract class:
   ```dart
   abstract class <E>Repository {
     Future<List<<E>>> listForCalendarDay(DateTime dayLocal);
     Future<<E>?> getById({required int id, required String modelTypeName});
     Future<int> create(<E> e, String modelTypeName);
     Future<int> update(<E> e, {String? modelTypeNameIfChanged});
     Future<void> delete(int id);
   }
   ```
3. **`lib/data/<e>/<e>_attr_keys.dart`** — `const String` constants for
   every KGQL attribute key your mapper reads/writes. One source of truth.
4. **`lib/data/<e>/<e>_mapper.dart`** — pure functions:
   - `<E> <e>FromModel(Model m)` — uses `m.attrString(key)`,
     `m.attrDateTime(key)`, etc. from `package:nx_db/kgql.dart`.
   - `SetModelRequest setKgql<E>Create(<E> e, ModelType schema)` — uses
     `setKgqlCreate(...)` from `package:nx_db/kgql.dart`.
   - Same for `Update` / `Delete`.
5. **`lib/data/<e>/kgql_<e>_repository.dart`** — implements the domain
   repository. **Constructor takes `GraphQLClient` and any schema-loader
   `Future<ModelType> Function()`s — never a Riverpod `Ref`.** Example:
   ```dart
   class Kgql<E>Repository implements <E>Repository {
     Kgql<E>Repository({required this.client, required this.loadSchema});
     final GraphQLClient client;
     final Future<ModelType> Function() loadSchema;
     // …
   }
   ```
   The reason: this repo is a `git mv` candidate to `nx_db/kgql/shared/`
   when a second app needs `<E>`. If it depends on `Ref`, it can't move.

### Riverpod wiring (`lib/data/providers.dart`)

This is the **only** file that combines all three: `nx_db/auth.dart`,
`nx_db/riverpod.dart`, and your app's repositories. It hands `Ref` to
nobody — it just constructs `Ref`-free repos and exposes them.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';

import 'package:nx_<yourapp>/domain/<e>/<e>_repository.dart';
import 'package:nx_<yourapp>/data/<e>/<e>_schema_provider.dart';
import 'package:nx_<yourapp>/data/<e>/kgql_<e>_repository.dart';

final <e>RepositoryProvider = Provider<<E>Repository>(
  (ref) => Kgql<E>Repository(
    client: ref.read(graphqlClientProvider),
    loadSchema: () => ref.read(<e>SchemaProvider.future),
  ),
);

/// Resolves only when auth has loaded a non-null user. KGQL providers
/// should depend on this so requests don't race ahead of the resolved client.
final authenticatedUserProvider = FutureProvider<User>((ref) async {
  final user = await ref.watch(authProvider.future);
  if (user == null) throw StateError('Not authenticated');
  return user;
});
```

`graphqlClientProvider` (from `nx_db/riverpod.dart`) automatically
rebuilds the `GraphQLClient` whenever `userIdProvider` or
`endpointProvider` change. Sign-in ⟶ providers invalidate ⟶ repositories
get a fresh, authenticated client. You don't have to think about it.

### Why this structure makes promotion mechanical

When `<E>` becomes shared by ≥2 apps:

```
mv lib/domain/<e>/<e>.dart                  ../nx_db/lib/src/kgql/shared/<e>/
mv lib/domain/<e>/<e>_repository.dart       ../nx_db/lib/src/kgql/shared/<e>/
mv lib/data/<e>/<e>_attr_keys.dart          ../nx_db/lib/src/kgql/shared/<e>/
mv lib/data/<e>/<e>_mapper.dart             ../nx_db/lib/src/kgql/shared/<e>/
mv lib/data/<e>/kgql_<e>_repository.dart    ../nx_db/lib/src/kgql/shared/<e>/
```

…then add `lib/<e>.dart` in `nx_db` re-exporting them, swap the app's
imports from `package:nx_<yourapp>/{domain,data}/<e>/...` to
`package:nx_db/<e>.dart`, delete the now-duplicate Riverpod providers
from `lib/data/providers.dart` and use the shared ones, and you're
done. No code changes — only imports.

---

## 6. The features layer

Features are the screens, view-models, and feature-local Riverpod
providers. They sit at the top of the import graph.

### Hard rules for `features/`

- **May import:** `package:flutter/...`, `package:flutter_riverpod/...`,
  `package:nx_db/auth.dart`, your own `core/`, `domain/`, `data/`, and
  any sibling `features/`.
- **MUST NOT import:** `package:nx_db/nx_db.dart`, `package:nx_db/kgql.dart`,
  `package:nx_db/riverpod.dart`, `package:nx_db/internal.dart`, or
  `package:graphql_flutter/...`.
- The only `nx_db` types a feature ever sees are `User`, `BackendPreset`,
  and friends from `auth.dart`. Everything else comes through your
  `domain/` types via providers in `data/providers.dart`.

If a feature needs `Model` or `ModelType`, that's the signal that the
KGQL-aware logic should move into `data/` and the feature should consume
a typed projection. (See `action_subtypes_provider.dart` ⟶
`actionCategoryOptionsProvider` in `nx_time` for the pattern.)

### Feature folder shape

```
features/<feature>/
  <feature>_page.dart              # the Scaffold / main widget
  <feature>_view_model.dart        # AsyncNotifier or Provider that maps domain → UI state
  <feature>_providers.dart         # if you have ≥2 feature-local providers, group them here
  widgets/                         # widgets used by ONLY this feature
    <small_widget>.dart
```

A view-model's job is to take `domain/` types and produce
**presentation-shaped** values (formatted strings, picker options, sort
orders) that the page can render directly. It **never** reaches into
`data/` to call repositories — it watches `Provider`s exposed by `data/`.

### App shell

The `AppShell` widget under `features/shell/` is the chrome around all
authed routes — bottom nav, drawer, scaffold. The hamburger button or
profile menu lives here too (e.g. `nx_app_menu_button.dart`), because
sign-out is a feature concern, not a `core/` concern.

---

## 7. Routing patterns to follow

`nx_time` uses **GoRouter with a single redirect** keyed off
`authProvider`. Stick to these conventions:

1. **One `routerProvider`, one redirect.** Don't sprinkle auth checks
   into individual route guards. The redirect is the only place that
   decides "logged in or not."
2. **Use `Provider.family<GoRouter, int>` with `initialTabIndex`.**
   Even if your app has one tab today, the family slot is what lets
   integration tests deep-link to a screen. It costs nothing to add.
3. **`refreshListenable` is a `ValueNotifier` driven by
   `ref.listen(authProvider, ...)`.** Anything else (rolling your own
   stream, watching from inside the redirect) is a footgun. Copy the
   pattern from `nx_time/lib/router.dart`.
4. **Nested navigation inside a tab uses `Navigator.of(context).push`,
   not `GoRouter.of(context).push`.** Tab content is a normal Material
   widget tree. Top-level routes (`/login`, `/home`, etc.) are the
   GoRouter routes; everything below the shell is regular Navigator.
5. **No deep links across auth state.** If a deep link arrives while
   unauthenticated, the redirect sends to `/login`; you do **not** stash
   the intended destination. Apps that need that should add a `?next=`
   query param convention explicitly.

When you add a new top-level route, add it as a sibling to `/login` and
`/home` in the router. When you add a tab, add it inside `AppShell`.

---

## 8. Tests folder

Mirror `lib/` exactly. The same rule that applies to `nx_db` applies
here: one test file per source file, placed at the same path under
`test/`.

```
nx_<yourapp>/test/
  _support/
    pump_app.dart                  # pumpAppWith({overrides, child}) helper
    riverpod_helpers.dart          # makeContainer({overrides})
    mock_graphql_client.dart       # mocktail-based MockGql + okQueryResult
    fake_<e>_repository.dart       # in-memory implementations of domain repos
    integration_auth.dart          # helpers for live-backend integration tests
    screenshot_auth.dart           # helpers for screenshot integration tests

  core/
    theme/<x>_test.dart
    formatting/<x>_test.dart
    time/<x>_test.dart

  domain/                           # PURE DART — no Flutter imports
    <e>/
      <e>_test.dart
      <e>_<aspect>_test.dart       # one file per aspect (e.g. action_category)

  data/
    <e>/
      <e>_attr_keys_test.dart
      <e>_mapper_test.dart
      kgql_<e>_repository_test.dart # mocked GraphQLClient — no Riverpod
    providers_test.dart             # asserts wiring (which class each provider exposes)

  features/
    <feature>/
      <feature>_view_model_test.dart  # ProviderContainer + FakeRepository

  widget/
    <yourapp>_login_screen_test.dart  # widget tests for screens

  layering/                          # GUARD TESTS — keep these in EVERY app
    no_flutter_in_domain_test.dart   # asserts lib/domain has no flutter / riverpod / nx_db imports
    no_nx_db_in_features_test.dart   # asserts lib/features only imports package:nx_db/auth.dart

  integration/                       # opt-in; live PGDB
    crud_round_trip_integration_test.dart
    <yourapp>_integration_test.dart
```

### What each test layer asserts

| Layer | What you test | Mocks / fakes |
|---|---|---|
| `domain/` | Pure data classes, value semantics, derived computations. | none |
| `data/<e>/<e>_mapper_test.dart` | `Model` ⟶ `<E>` and `<E>` ⟶ `SetModelRequest` round-trips. | none |
| `data/<e>/kgql_<e>_repository_test.dart` | The GraphQL contract: which document, which variables, parsing. | `MockGraphQLClient` |
| `data/providers_test.dart` | Riverpod wiring (which class each provider returns). | overrides on `graphqlClientProvider` |
| `features/<feature>/<x>_view_model_test.dart` | View-model state under various inputs. | `Fake<E>Repository` overrides on `<e>RepositoryProvider` |
| `widget/` | Widget rendering and tap behavior. | repository fakes + `pumpAppWith` |
| `layering/` | Architectural rules. | reads `lib/` source files, scans imports |
| `integration/` | End-to-end with a real backend. | none — requires `RUN_<YOURAPP>_INTEGRATION=true` |

### Layering tests — copy these verbatim

These two tests are your earliest warning system that the architecture
is decaying. Copy them into every new app and let CI run them on every
push.

`test/layering/no_flutter_in_domain_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/domain avoids Flutter, Riverpod, and nx_db', () {
    final dir = Directory('lib/domain');
    expect(dir.existsSync(), isTrue);
    const forbidden = [
      'package:flutter/',
      'package:flutter_riverpod/',
      'package:nx_db/',
    ];
    final offenders = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final f in forbidden) {
        if (text.contains(f)) offenders.add('${entity.path}: $f');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
```

`test/layering/no_nx_db_in_features_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/features may only import package:nx_db/auth.dart', () {
    final dir = Directory('lib/features');
    expect(dir.existsSync(), isTrue);
    final offenders = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final line in entity.readAsStringSync().split('\n')) {
        final t = line.trimLeft();
        if (!t.startsWith('import ') && !t.startsWith('export ')) continue;
        if (!t.contains('package:nx_db/')) continue;
        if (t.contains("package:nx_db/auth.dart'")) continue;
        offenders.add('${entity.path}: $t');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
```

---

## 9. Decision tree — where does this code go?

| You're adding… | It goes in… | Imports allowed |
|---|---|---|
| A new route (`/foo`) | `lib/router.dart` | `nx_db/auth.dart`, your features |
| Sign-in UI | `lib/features/auth/<yourapp>_login_screen.dart` | `nx_db/auth.dart`, your `core/` |
| Bottom-nav / shell chrome | `lib/features/shell/app_shell.dart` | feature pages, `core/widgets`, `core/theme` |
| A new screen | `lib/features/<feature>/<feature>_page.dart` | siblings, `domain/`, `data/`, `core/`, `nx_db/auth.dart` |
| State for that screen | `lib/features/<feature>/<feature>_view_model.dart` | as above |
| A typed business object | `lib/domain/<e>/<e>.dart` | **pure Dart only** |
| A repository contract | `lib/domain/<e>/<e>_repository.dart` | pure Dart |
| Implementation of that contract over KGQL | `lib/data/<e>/kgql_<e>_repository.dart` | `package:nx_db/kgql.dart`, `package:graphql_flutter` |
| `Model` ⟷ entity conversion | `lib/data/<e>/<e>_mapper.dart` | `package:nx_db/kgql.dart` |
| KGQL attribute keys | `lib/data/<e>/<e>_attr_keys.dart` | none |
| Riverpod binding for a repository | `lib/data/providers.dart` | `nx_db/{auth,riverpod}.dart`, your `data/`, `domain/` |
| A feature-local Riverpod provider | `lib/features/<feature>/<feature>_providers.dart` | `flutter_riverpod`, `domain/`, `data/`, **never** `kgql.dart` |
| Generic widget reused by many features | `lib/core/widgets/<x>.dart` | `flutter`, `core/theme` |
| Theme color, text style, spacing constant | `lib/core/{theme,layout}/<x>.dart` | `flutter` |
| A pure formatting helper | `lib/core/formatting/<x>.dart` | `intl`, pure Dart |
| A new GraphQL operation document | **`nx_db/lib/src/kgql/documents/`** — not in your app | — |
| A typed entity used by ≥2 apps | **promote to `nx_db/lib/src/kgql/shared/<e>/`** — not in your app | see `nx_db_app_boundary.md` |

---

## 10. Rollout order — zero to working app

For a brand-new app, do these steps in this order. Each step ends with
"the app still runs / the tests still pass," so you can stop at any
point and the codebase is consistent.

1. **Step 1 — Skeleton.** Create the package, the four top-level
   folders, and `main.dart` + `app.dart` + `router.dart`. Add a
   placeholder `AppShell` and `<yourapp>_login_screen.dart` that just
   render `Text('login')` and `Text('home')`. **Outcome:** the app
   compiles, redirects unauthenticated to `/login`, and shows the
   placeholder login.
2. **Step 2 — Real login screen.** Wire the `userId` field +
   `BackendPreset` dropdown + `authProvider.notifier.login(...)` call
   following `time_login_screen.dart`. **Outcome:** real sign-in works,
   you land on the placeholder home.
3. **Step 3 — Layering tests.** Add the two layering tests from
   section 8 above. They should pass with the empty `domain/` and the
   placeholder `features/`. **Outcome:** CI starts catching boundary
   violations from day one.
4. **Step 4 — First entity, top-down.**
   1. Define the typed class in `domain/<e>/<e>.dart`.
   2. Define the abstract `<E>Repository` in
      `domain/<e>/<e>_repository.dart`.
   3. Build a `Fake<E>Repository` in `test/_support/`.
   4. Build the first feature page + view-model that consumes
      `<e>RepositoryProvider`. Override it with the fake in
      `test/features/<feature>/<x>_view_model_test.dart`.
   5. **Outcome:** the feature renders end-to-end against fake data.
5. **Step 5 — Wire the entity to KGQL.**
   1. Write `<e>_attr_keys.dart`, `<e>_mapper.dart`,
      `kgql_<e>_repository.dart`, and `<e>_schema_provider.dart`.
   2. Add `<e>RepositoryProvider` to `data/providers.dart`,
      constructing the `Ref`-free repo from `graphqlClientProvider` +
      schema loaders.
   3. Write the mapper test (no I/O), the repository test (mocked
      `GraphQLClient`), and a `data/providers_test.dart` smoke that
      asserts the provider returns a `Kgql<E>Repository`.
   4. **Outcome:** the feature now reads real data from the backend.
6. **Step 6 — Add an integration test.** Copy
   `test/_support/integration_auth.dart` from `nx_time` and write one
   end-to-end CRUD test under `test/integration/`. Gate it behind
   `RUN_<YOURAPP>_INTEGRATION=true` so it doesn't run in default CI.
   **Outcome:** real-backend regressions are catchable on demand.
7. **Step 7 — Repeat 4–6 for each entity.** By the third entity, the
   pattern is mechanical.
8. **Step 8 — Promote when shared.** When a second app needs an entity,
   stop. Move the four files to `nx_db/lib/src/kgql/shared/<e>/`, add a
   `lib/<e>.dart` re-export in `nx_db`, swap your imports, and delete
   the local copies. See `mobile/nx_db/plans/current/nx_db_app_boundary.md`
   for the full promotion recipe.

If you're stuck on any step, open the equivalent file in `nx_time` and
mirror it. `nx_time` exists specifically as the reference
implementation — the moment its architecture and this guide diverge,
update both.
