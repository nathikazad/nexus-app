# nx_cards

`nx_cards` helps a person collect knowledge and retain it through repeated
study. Its source tree tells that story before it explains the framework:

```text
main.dart
  -> app/            Flutter root, routes, and theme
  -> browser/        finding cards through languages and books
     -> data/
        -> kgql/     fetch and translate the server representation
        -> models/   application-ready card vocabulary
     -> language/    language and word-category browsing
     -> card_list/   reusable card-list presentation
  -> study/          choosing and conducting a study session
     -> language/
        -> drawing/  handwriting and script recall
     -> session/     active review and recap
  -> scheduling/     deciding when a card returns and how it progresses
  -> tutor/          AI-assisted voice study
  -> sync/
     -> native/      Drift, local reads, and the mutation outbox
     -> remote/      upload and snapshot transport
  -> audio/          downloading and caching card audio
  -> account/        login and account access
  -> settings/       user-controlled application preferences
```

## Reading the application

Start at `main.dart`, then read `app/recall_app.dart` and `app/routes.dart` to
see how Recall starts and which page it opens. From there, follow the product
capability you care about. Each capability owns its production wiring: for
example, `browser/browser_providers.dart` selects the native or web library,
while `sync/sync_providers.dart` assembles Drift, the outbox, and remote sync.

Each capability exposes a same-named facade (`browser/browser.dart`,
`study/study.dart`, and so on). Code outside a capability should prefer that
facade over its implementation folders.

Inside `browser/data/`, information flows in one direction:

```text
kgql -> models -> browser and study UI
```

`models/` and scheduling policies are pure application vocabulary. `kgql/`
knows the server representation, while `sync/native/` knows Drift and the
outbox. UI code must not know either persistence representation.

## Runtime story

1. `account/` restores an authenticated or cached account.
2. `sync/` opens the account's local library and refreshes it when possible.
3. `browser/` presents language and book collections.
4. `study/` converts a collection and the person's choices into a session.
5. `scheduling/` records each answer and calculates the next review.
6. `tutor/` can conduct the same session through a live voice agent.

Native builds are local-first: Drift is the readable state and changes are
queued through the outbox. Web builds use the remote KGQL library directly.

## OpenAI build configuration

AI study requires `OPENAI_API_KEY` from the Git-ignored
`../nx_live_agent/.env`. Release compilation fails when the Dart define is
missing. The shared Shorebird release and patch commands validate that file
and pass it automatically:

```text
# Run from mobile/.
scripts/shorebird_apps.sh release nx_cards
scripts/shorebird_apps.sh patch nx_cards
```

For a direct local Flutter run, pass
`--dart-define-from-file=../nx_live_agent/.env` explicitly.

## Boundaries

- `main.dart` stays a tiny entrypoint.
- Business policy does not import Flutter, Riverpod, KGQL, Drift, or HTTP.
- Each capability owns its providers and production adapters.
- `app/` contains only the Flutter root, routes, and theme.
- Capability code imports another capability through its public facade.
- New generic top-level `core/`, `data/`, `domain/`, `features/`, or `utils/`
  roots are not allowed; top-level folders should name part of the product
  story. Technical folders such as `data/` are scoped beneath their owner.
- A folder represents a real cluster. Do not create a folder for one file.
- Prefer a cohesive module over a separate file for every enum, value object,
  or provider; split only when the resulting files are independently useful.
- Tests mirror the production capability tree.

## KGQL setup

After login, the app detects missing model types or required attributes and
presents an explicit setup action. Ordinary startup does not mutate schemas.
