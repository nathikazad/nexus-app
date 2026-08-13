# Ideal Mobile App Architecture

## The thesis: the source tree tells the story

The architecture should follow Robert C. Martin's principle that a building's
architecture announces its purpose. When a developer opens an application for
the first time, the folders should scream what the application does—not which
framework, database, or state-management library it uses.

The tree is the application's table of contents. It should present a linear
narrative: how the app starts, what the user can do, how one action leads to
the next, and which supporting capabilities make that journey possible. A new
developer should be able to describe the product from the tree before reading
implementation code, then zoom directly to the likely home of a behavior or
bug.

```text
main -> app -> account -> browse -> study -> schedule -> sync
                                  -> tutor
```

The exact story differs by app. The invariant is that product language and
workflow come first; Flutter, Riverpod, KGQL, Drift, and HTTP remain details.

## Organize as a readable narrative

Top-level folders name user-visible capabilities or essential product
responsibilities. Avoid generic top-level buckets such as `core`, `data`,
`domain`, `features`, and `utils`: they describe software categories but say
almost nothing about the application.

```text
lib/
  main.dart          where execution begins
  app/               startup, routes, and visual shell
  account/           gaining access
  browser/           finding something to learn
  study/             learning it
  scheduling/        deciding when it returns
  tutor/             conducting assisted study
  sync/              preserving and exchanging changes
  settings/          controlling application behavior
```

Inside a capability, continue the story. Name folders after successive parts
of the workflow, not after framework layers. A reader should be able to move
from the broad narrative to a specific screen, policy, or adapter without
searching the whole repository.

Technical distinctions are useful when scoped beneath the capability that
owns them. For a data-backed capability, the flow should be visible:

```text
browser/
  data/
    kgql/            fetches and translates the server representation
    models/          application-ready vocabulary
  language/          language browsing and category behavior
  card_list/         reusable list behavior and presentation
```

This reads linearly as external data to application models to product
behavior. Backend schemas, database rows, and transport objects never become
the vocabulary of the UI.

## Build from tested modules with clean interfaces

Each important behavior should live in a cohesive module with a small,
explicit interface and focused unit tests. Scheduling, queue construction,
mapping, progression, synchronization, and study policies should be testable
without launching the whole app.

Prefer composition over growing conditional trees:

- Select platform and backend implementations at assembly boundaries.
- Express varying behavior through policies, strategies, or collaborators.
- Compose a workflow from independently testable parts.
- Avoid scattering `if web`, `if offline`, `if language`, and `if book`
  throughout shared code.
- Keep unavoidable product decisions close to the capability that owns them.

Composition is valuable because it reduces the number of states a reader must
hold in mind. It is not a reason to create an interface and file for every
class. A module earns its boundary when it has a coherent responsibility, a
meaningful contract, and useful independent tests.

## Avoid both monoliths and confetti

Modularity must improve navigation. Too little produces giant files and
branch-heavy systems; too much replaces understanding with hundreds of tiny
files and folders.

Use 50–1000 lines as the normal range for a production Dart file:

- Below roughly 50 lines, first ask whether the declarations belong with a
  closely related concept. Tiny enums, value objects, providers, and wrappers
  usually compose better into one cohesive module.
- Above roughly 1000 lines, split by a recognizable step in the product
  narrative or by an independently testable responsibility.
- These are strong heuristics, not mechanical laws. A tiny public facade or
  boundary contract may be valuable; generated files are exempt.
- Never add filler to meet a line target, and never split a cohesive idea only
  to reduce its line count.

A folder must represent a real cluster. Do not create a folder for one file.
Do not preserve empty folders, obsolete routes, compatibility layers, or dead
adapters: they make the tree tell a false story.

## Boundaries support the narrative

Architectural boundaries exist to keep the story readable:

- Application models and policies do not import UI frameworks, databases,
  network clients, or backend schemas.
- UI consumes application-ready models and capability interfaces.
- Backend adapters own fetching, mutation, external schemas, and mapping.
- Offline storage and synchronization own persistence mechanics, not product
  policy.
- Platform-specific implementations sit behind interfaces selected during app
  assembly.
- Capability entry points expose what neighbors need without exposing internal
  machinery.

The normal dependency direction is:

```text
external representation -> application model -> product workflow -> UI
```

Dependencies pointing backward require an explicit reason.

## Tests preserve the architecture

Tests should mirror the production narrative so a developer can predict where
the corresponding test lives. Unit tests protect policies and modules;
integration and widget tests protect composition and user journeys.

Architecture tests should enforce the few rules that keep the tree truthful:
allowed top-level capabilities, persistence-free models, isolated backend and
database adapters, and the absence of obsolete generic roots. Tests should
protect understanding, not freeze every incidental folder choice.

## The standard of success

The architecture succeeds when a new developer can:

1. Look at the tree and explain the application's purpose and main journey.
2. Follow that journey linearly from startup to the relevant capability.
3. Predict where a feature or defect belongs before searching.
4. Open a small number of cohesive files and understand the behavior.
5. Change a tested module through a clean interface without learning the whole
   system.

The goal is not maximum abstraction or minimum file count. The goal is a code
base whose structure communicates the product clearly, supports safe
composition, and lets a human zoom from the whole story to one detail with as
little friction as possible.
