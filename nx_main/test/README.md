# `nexus_voice_assistant` (`nx_main`) tests

## Fast suite (default)

From `mobile/nx_main`:

```bash
flutter pub get
flutter test
```

Live KGQL tests under `test/integration/` are **skipped** unless the environment variable is set:

```bash
RUN_NX_MAIN_INTEGRATION=true flutter test test/integration
```

They expect a reachable GraphQL endpoint for `BackendPreset.piLan` (see `nx_db`).

## Layout

- `test/_support/` — mocks and fakes shared by unit tests
- `test/data/` — mappers, HTTP services, repositories (mocked I/O)
- `test/domain/` — pure Dart entities
- `test/features/` — view-models and (later) widget tests
- `test/integration/` — opt-in live PGDB / KGQL
- `test/layering/` — import-rule guards

Tag metadata lives in `dart_test.yaml`. To exclude by tag:

```bash
flutter test --exclude-tags=integration
```
