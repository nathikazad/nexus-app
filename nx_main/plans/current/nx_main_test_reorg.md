# `nx_main` test suite reorganization plan

Companion to [`nx_main_reorg.md`](./nx_main_reorg.md). The `lib/` reorg
moved everything into a strict **core / domain / data / features**
layering, added abstract repositories for images / battery / model-type
write, and split the schema-navigator form into domain state + KGQL
repository + feature view-model. The test suite is several years
behind: three live-server scripts under `test/data/schema/` plus the
two layering tests added in step 11. Almost no existing test code
carries over unchanged. This document records where coverage stands
today and how to restructure the suite so each layer is testable in
isolation, with a few integration tests reserved for things that only
the live PGDB and a real BLE necklace can answer.

This plan mirrors the structure of
[`nx_time_test_reorg.md`](../../../nx_time/plans/current_plan/nx_time_test_reorg.md)
on purpose — both apps follow the same four-layer rules and should
have the same shape of test tree. The differences below come entirely
from `nx_main`'s extra surface area: BLE / WebSocket / background
isolate, AI MCP tooling, voice-transcript bridge, image / battery
HTTP, and the schema-navigator admin UI.

## Where the suite stands today

### What exists

| Path | Purpose |
|------|---------|
| `test/integration/schema_model_type_struct_live_test.dart` | Live: prints `GetAllModelTypes`, asserts fixture tree. Skipped unless `RUN_NX_MAIN_INTEGRATION=true`. |
| `test/integration/kgql_model_type_live_test.dart` | Live: create / update / delete `ModelType` against `piLan`. |
| `test/integration/kgql_model_repository_live_test.dart` | Live: Person + Company CRUD against `piLan`. |
| `test/data/schema/kgql_model_type_repository_test.dart` | Unit: mocked `GraphQLClient` for `KgqlModelTypeRepository`. |
| `test/layering/no_nx_db_in_features_test.dart` | AST scan of `lib/features/**` — no `package:nx_db/` other than `auth.dart`. |
| `test/layering/no_flutter_in_domain_test.dart` | AST scan of `lib/domain/**` — no Flutter, Riverpod, or `nx_db`. |

Everything else is untested. There is **no** `_support/` folder, **no**
fakes, **no** `dart_test.yaml`, **no** widget test, and **no** view-model
test. The three "data/schema" files use a hand-rolled
`TestAuthController` and reach the live backend; they are integration
tests in everything but folder name.

### Coverage by surface area (target `lib/` layout vs existing tests)

| New `lib/` location | Test today | Coverage |
|---|---|---|
| `core/theme/app_theme.dart` | none | smoke only |
| `core/layout/layout.dart` | none | n/a (constants) |
| `core/logging/{logging_service,log_entry}.dart` | none | **gap** — log buffering + ring semantics |
| `core/audio/audio_stream_manager.dart` | none | **gap** — Opus framing tricky to test, smoke at least |
| `core/widgets/{loading_indicator,error_widget,attribute_field,message_bubble,input_area,expanding_fab_menu,timeline_slider}.dart` | none | **gap** (golden the stable ones) |
| `domain/ble/{ble_connection_state,ble_constants,battery_data,camera_record_status}.dart` | none | **gap** — pure value types, easy to test |
| `domain/images/image_entry.dart` | none | **gap** |
| `domain/images/image_repository.dart` (interface) | n/a | n/a |
| `domain/battery/battery_point.dart` | none | **gap** |
| `domain/battery/battery_repository.dart` (interface) | n/a | n/a |
| `domain/ai/{interaction,interaction_manager}.dart` | none | **gap** — message stream owner; pure Dart |
| `domain/voice/voice_transcript.dart` | none | **gap** — `copyWithMessage` semantics |
| `domain/schema/*` (drafts + form fields + `ModelTypeWriteRepository`) | none | **gap** — pure data, easy to test |
| `data/providers.dart` | none | smoke only |
| `data/ble/bg_ble_client.dart` | none | **gap** — driver, needs a fake `flutter_blue_plus` |
| `data/socket/bg_socket_client.dart` | none | **gap** — needs a fake `WebSocketChannel` |
| `data/background/background_service.dart` | none | **gap** — orchestrator; isolate seam is hard, mock `AndroidServiceInstance` |
| `data/hardware/{hardware_service,rtc_service,paired_device_storage,camera_command}.dart` | none | **gap** — `paired_device_storage` is pure SharedPreferences and the easiest win |
| `data/watch/watch_bridge_service.dart` | none | **gap** — method-channel; mock the channel |
| `data/images/image_service.dart` | none | **gap** — HTTP, `MockClient` |
| `data/images/http_image_repository.dart` | none | smoke; thin delegate |
| `data/battery/battery_chart_service.dart` | none | **gap** — HTTP, `MockClient` |
| `data/battery/http_battery_repository.dart` | none | smoke |
| `data/ai/agent_tool_service.dart` | none | **gap** — MCP wire format |
| `data/voice/{voice_transcript_mapping,voice_transcript_notifier}.dart` | none | **gap** — `mapTranscript`/`mapTranscriptMessage` are pure; notifier needs a fake `TranscriptService` |
| `data/schema/schema_entity_mappers.dart` | none | **gap** — biggest **mapping risk** in the navigator (KGQL ↔ domain) |
| `data/schema/kgql_schema_providers.dart` | none | smoke (overrides + projection) |
| `data/schema/kgql_model_type_repository.dart` | live integration (`kgql_model_type_repository_test.dart`) | **gap at unit level** (mocked `GraphQLClient`) |
| `features/voice/voice_assistant_page.dart` | none | **gap** |
| `features/hardware/{hardware_page,device_selection_page,widgets/camera_section}.dart` | none | **gap** |
| `features/data_browser/{data_page,images_page,battery_page}.dart` | none | **gap** — biggest UI gap; both pages have non-trivial timeline / chart math |
| `features/logs/log_viewer_page.dart` | none | **gap** |
| `features/auth/login_page.dart` | none | **gap** |
| `features/splash/splash_page.dart` | none | **gap** |
| `features/home/home_page.dart` | none | **gap** |
| `features/schema_navigator/models_page.dart` | none | **gap** — tree filter / expansion logic |
| `features/schema_navigator/model_type_detail_page.dart` | none | **gap** — inheritance section, tag-systems rendering |
| `features/schema_navigator/model_type_form_page.dart` | none | **gap** — load-into-form + save → repo |
| `features/schema_navigator/model_type_form_view_model.dart` | none | **gap** — biggest view-model gap; create vs edit branching, delete-marking, validation |
| `features/schema_navigator/{relationship_form_page,model_form_page,model_type_selector_page,models_list_page,model_detail_page}.dart` | none | **gap** |
| `features/schema_navigator/widgets/*` | none | **gap** |
| Live integration | three KGQL scripts under `test/data/schema/` | strong for write paths against `piLan`; **no read-only schema integration test**, **no BLE / hardware integration** (manual only) |

### Things that will break in-place when more of `nx_main_reorg.md` lands

- The three `test/data/schema/*_test.dart` files import
  `package:nx_db/nx_db.dart` directly and call providers (`modelTypesProvider`,
  `graphqlClientProvider`). After the **strip-KGQL-from-features** step
  (reorg step 10 — already done) these stay valid, but they are
  *integration* tests — they should physically move to `test/integration/`
  under the new `dart_test.yaml` `integration` tag and run only when
  `RUN_NX_MAIN_INTEGRATION=true`. Today they run on every `flutter test`
  invocation and fail offline.
- They reference the **legacy** form-state class
  (`SetModelTypeRequest` from `nx_db`) directly. The unit equivalent of
  these tests should target the new
  `lib/data/schema/kgql_model_type_repository.dart` (which now wraps
  the mutation behind `ModelTypeWriteRepository`), not the raw
  `SetModelTypeRequest`. The live versions can keep the raw call.
- The two `test/layering/*` tests are correct as-is and stay.

### Why the structure itself is wrong (not just stale paths)

1. **Three live tests do not match a five-layer codebase.** There is
   no place to add a domain test, a view-model test, a widget test, a
   pure data-mapper test, or a hardware-driver test with a fake
   `flutter_blue_plus`.
2. **Every existing test depends on the live backend.** `flutter test`
   on a fresh checkout fails offline. This is the single biggest
   reason regressions sneak in: nobody runs the suite locally.
3. **`data/schema/schema_entity_mappers.dart` has zero coverage.** It
   is the new translation seam between `nx_db` and the navigator
   domain types — exactly the kind of code that quietly breaks when
   `nx_db` adds a field. It is also pure Dart with no I/O; the
   easiest win in the whole suite.
4. **`features/schema_navigator/model_type_form_view_model.dart` has
   zero coverage.** The create-vs-edit branching, delete-marking of
   attributes / relations (replace-with-`delete:true` instead of
   removing-from-list), and load-once gating are exactly the rules
   that broke when the form was first built. They are pure-Dart on a
   `ProviderContainer` once a fake `ModelTypeWriteRepository` exists.
5. **Hardware / BLE / background isolate has never been tested.** The
   reorg pulled `BleConstants`, `BleConnectionState`, `BatteryData`
   into `domain/ble/` precisely so `data/ble/bg_ble_client.dart` could
   be tested with a fake `flutter_blue_plus`. The plumbing is there;
   the tests are not.
6. **Image / battery pages talk to the network in tests if they're
   ever pumped.** With `imageRepositoryProvider` /
   `batteryRepositoryProvider` now in `data/providers.dart`, these
   pages can be widget-tested with a fake repository injected via
   `ProviderScope.overrides` — but only if `_support/` actually
   provides a `FakeImageRepository` / `FakeBatteryRepository`.
7. **Voice transcript bridge has no tests.** `mapTranscript` /
   `mapTranscriptMessage` are pure functions; `VoiceTranscriptNotifier`
   subscribes to a static `TranscriptService.streamMessages` — that
   static call is the test seam that needs a fake.
8. **No layering enforcement of `data/`.** The two existing layering
   tests cover `domain/` and `features/`. Nothing prevents `data/`
   from importing `package:nexus_voice_assistant/features/...`. Add
   the third rule.

## Target layout — mirror `lib/` exactly

Every layer gets its own folder. One test file per source file.
Domain tests are pure Dart; data tests use mocked GraphQL clients,
mocked HTTP, fake BLE / WebSocket / SharedPreferences; feature tests
split into pure-Dart view-model tests + Flutter widget tests + a few
integration tests that need the live backend.

```
nx_main/test/
  _support/
    pump_app.dart                       # tester.pumpAppWith({overrides, page})
    riverpod_helpers.dart               # makeContainer({overrides}) helper
    mock_graphql_client.dart            # re-export of nx_db's helpers
    mock_http_client.dart               # http: package MockClient builders
    fake_image_repository.dart          # in-memory ImageRepository
    fake_battery_repository.dart        # in-memory BatteryRepository
    fake_model_type_write_repository.dart # in-memory ModelTypeWriteRepository
    fake_schema_data.dart               # canned SchemaModelType / SchemaModel trees
    fake_ble_client.dart                # stand-in for FlutterBluePlus surface used by bg_ble_client
    fake_socket_channel.dart            # WebSocketChannel double
    fake_transcript_service.dart        # stubs TranscriptService.getTranscript / streamMessages
    integration_auth.dart               # TestAuthController + integrationOverrides for live tests
    layering_test_helpers.dart          # AST-based import scanner (shared with the existing tests)

  core/
    theme/
      app_theme_test.dart               # ColorScheme instances are stable
    logging/
      log_entry_test.dart
      logging_service_test.dart         # ring-buffer add/clear, level filtering
    audio/
      audio_stream_manager_test.dart    # frame size math; doesn't touch hardware
    widgets/
      loading_indicator_test.dart       # smoke + golden
      error_widget_test.dart            # message rendering + retry callback
      attribute_field_test.dart
      message_bubble_test.dart          # golden(s)
      input_area_test.dart              # callback wiring
      expanding_fab_menu_test.dart      # open / close / item tap
      timeline_slider_test.dart         # value clamp, mark hit-test

  domain/
    ble/
      ble_connection_state_test.dart    # enum / equality
      ble_constants_test.dart           # UUIDs are non-empty, well-formed
      battery_data_test.dart            # parse / fromBytes
      camera_record_status_test.dart
    images/
      image_entry_test.dart
    battery/
      battery_point_test.dart
    ai/
      interaction_test.dart
      interaction_manager_test.dart     # stream pushes through; close cancels
    voice/
      voice_transcript_test.dart        # copyWithMessage replaces by id, append otherwise
    schema/
      attribute_definition_draft_test.dart
      relation_definition_draft_test.dart
      schema_model_type_test.dart       # copyWith retains other fields
      model_type_form_state_test.dart   # ModelTypeFormFields.fromSchemaModelType maps cleanly

  data/
    providers_test.dart                  # smoke: provider tree composes; overrides apply
    ble/
      bg_ble_client_test.dart            # uses fake_ble_client; covers connect / scan / write
    socket/
      bg_socket_client_test.dart         # uses fake_socket_channel; reconnect, send-after-open
    background/
      background_service_test.dart       # orchestrator: ble events → socket forward (mock both)
    hardware/
      hardware_service_test.dart
      rtc_service_test.dart
      paired_device_storage_test.dart    # SharedPreferences.setMockInitialValues
      camera_command_test.dart
    watch/
      watch_bridge_service_test.dart     # method-channel mock
    images/
      image_service_test.dart            # http: MockClient — fetchAvailableDates / fetchImagesForDay
      http_image_repository_test.dart    # smoke: delegates to image_service
    battery/
      battery_chart_service_test.dart    # MockClient — fetchBatteryDates / fetchBatteryDay
      http_battery_repository_test.dart  # smoke
    ai/
      agent_tool_service_test.dart       # MCP request/response shapes
    voice/
      voice_transcript_mapping_test.dart # pure: mapTranscript / mapTranscriptMessage
      voice_transcript_notifier_test.dart # uses fake_transcript_service
    schema/
      schema_entity_mappers_test.dart    # biggest data-layer gap: nx ↔ domain round-trip
      kgql_schema_providers_test.dart    # overrides nx providers, asserts projection
      kgql_model_type_repository_test.dart # mocked GraphQLClient (was a live test; live one moves)

  features/
    voice/
      voice_assistant_view_model_test.dart   # NEW once view-model lands (reorg step 9)
      voice_assistant_page_test.dart         # widget: pumps with fake transcript
    hardware/
      hardware_view_model_test.dart          # NEW
      hardware_page_test.dart                # widget: states (idle / scanning / connected)
      device_selection_page_test.dart
    data_browser/
      images_view_model_test.dart            # NEW: timeline + slider math
      images_page_test.dart                  # widget: pumps with FakeImageRepository, dates / day load
      battery_view_model_test.dart           # NEW: chart spots / X-axis
      battery_page_test.dart                 # widget: pumps with FakeBatteryRepository
    schema_navigator/
      model_type_form_view_model_test.dart   # biggest feature gap: create vs edit, delete-mark, save → repo
      model_type_form_page_test.dart         # widget: pumps with fake schema providers + fake write repo
      models_page_test.dart                  # tree filter / expansion
      model_type_detail_page_test.dart       # inheritance, tag systems
      model_type_selector_page_test.dart
      relationship_form_page_test.dart
      models_list_page_test.dart
      model_detail_page_test.dart
      widgets/
        attribute_definitions_section_test.dart
        relationships_section_test.dart
        model_type_basic_fields_test.dart
        model_type_tree_row_test.dart        # golden(s) when stable
        model_type_list_row_test.dart
        model_row_test.dart
    logs/
      log_viewer_page_test.dart
    auth/
      login_page_test.dart
    splash/
      splash_page_test.dart
    home/
      home_page_test.dart                    # bottom-nav tab switching

  layering/
    no_nx_db_in_features_test.dart           # already exists
    no_flutter_in_domain_test.dart           # already exists
    no_features_in_data_test.dart            # NEW: data/ must not import features/

  golden/                                    # generated PNGs, checked in
    schema_navigator/
    data_browser/
    core_widgets/

  integration/                               # opt-in: RUN_NX_MAIN_INTEGRATION=true
    kgql_model_type_live_test.dart            # was test/data/schema/kgql_model_type_repository_test.dart
    kgql_model_repository_live_test.dart      # was test/data/schema/kgql_model_repository_test.dart
    schema_model_type_struct_live_test.dart   # was test/data/schema/model_type_struct_test.dart
    images_battery_http_integration_test.dart   # NEW: hits real image server (RUN_NX_MAIN_HTTP_INTEGRATION)
    ble_smoke_integration_test.dart             # NEW (manual): pairs to a real necklace; @Tags(['hardware']), gated by RUN_NX_MAIN_BLE_INTEGRATION
```

### Updated `dart_test.yaml`

```yaml
tags:
  domain:      { description: "Pure Dart domain entity / repo-interface tests" }
  data:        { description: "Data-layer mappers & drivers (mocked GraphQL / HTTP / BLE / sockets)" }
  view_model:  { description: "Pure feature view-model tests" }
  widget:      { description: "Flutter widget / page tests with fake repositories" }
  golden:      { description: "Golden-image widget tests" }
  layering:    { description: "Architectural import-rule tests" }
  integration: { description: "Live PGDB / HTTP — requires RUN_NX_MAIN_INTEGRATION=true" }
  hardware:    { description: "Live BLE necklace — requires RUN_NX_MAIN_BLE_INTEGRATION=true" }
```

The default `flutter test --exclude-tags=integration --exclude-tags=hardware`
runs the entire fast suite (domain → data → view-model → widget → golden
→ layering). `RUN_NX_MAIN_INTEGRATION=true flutter test test/integration`
hits the live PGDB / image server. `RUN_NX_MAIN_BLE_INTEGRATION=true flutter test --tags=hardware`
needs a real necklace and is run manually.

## Coverage gaps that need new tests (priority order)

1. **`data/schema/schema_entity_mappers_test.dart`** — round-trip every
   conversion (`AttributeDefinition`, `RelationshipType`,
   `RelationAttributeDefinition`, `ModelType`, `Model`, `ModelAttribute`,
   `Relation`, `TagSystem`). Pure Dart, zero harness, biggest current
   risk: silent regressions when `nx_db` adds a field that the
   navigator depends on. Easiest win in the whole suite.
2. **`features/schema_navigator/model_type_form_view_model_test.dart`** —
   `loadModelTypeData` runs once; `removeAttributeDefinition` on an
   attribute with `id` flips `delete: true` rather than removing;
   `removeAttributeDefinition` on an unsaved attribute removes;
   `save` calls `repo.setModelType(...)` exactly once with the right
   parent-id / typeKind / drafts; create-vs-edit chooses the right
   id; success path invalidates `schemaModelTypesProvider` and (when
   editing) `schemaModelTypeProvider(id)`.
3. **`data/schema/kgql_model_type_repository_test.dart`** — mocked
   `GraphQLClient`; assert `setKgqlModelTypes` JSON shape, response
   parsing (`json` field as String *and* as Map), error path throws.
   The current live version becomes
   `integration/kgql_model_type_live_test.dart`.
4. **`data/voice/voice_transcript_mapping_test.dart`** —
   `mapTranscriptMessage` field-by-field; `mapTranscript` returns
   null for null input, preserves message id keys, maps every entry.
   Pure Dart, no harness.
5. **`data/voice/voice_transcript_notifier_test.dart`** — fake
   `TranscriptService` exposing `getTranscript()` and a controllable
   `streamMessages(id)`. Assert: build → loading; load → transcript +
   `isLoading: false`; new message → state has appended entry;
   `refresh()` re-subscribes; `onDispose` cancels the subscription.
6. **`data/images/image_service_test.dart`** + **`battery_chart_service_test.dart`** —
   `http: MockClient` returning canned JSON. Cover the
   `_normalizeBase` trailing-slash logic, `imageHeaders` Cloudflare
   conditional, malformed JSON throws the typed
   `ImageServiceException` / `BatteryChartException`.
7. **`features/data_browser/{images,battery}_view_model_test.dart`** —
   once view-models are extracted (reorg step 9). Pure-Dart math:
   slider min/max from entries, `_currentIndex` lookup, `_isToday`
   gating of polling, chart spots from `BatteryPoint`s.
8. **`features/data_browser/{images,battery}_page_test.dart`** — pump
   with a `FakeImageRepository` / `FakeBatteryRepository` returning a
   fixed list. Assert the date picker enables only on available days,
   the chart appears once data lands, the empty state shows the
   correct copy.
9. **`features/schema_navigator/models_page_test.dart`** — pump with
   the schema providers overridden by canned data. Assert: tree
   collapses by default, search expands matching subtrees, FAB pushes
   `/model-type-form`, refresh invalidates `schemaModelTypesProvider`.
10. **`data/ble/bg_ble_client_test.dart`** — fake `flutter_blue_plus`
    surface. Cover scan-results filtering by service UUID, connect →
    discover → notify subscription, write requests serialise
    correctly, `BleConnectionState` transitions on connect / disconnect.
11. **`data/socket/bg_socket_client_test.dart`** — fake
    `WebSocketChannel`. Cover: open → ready, queued sends drain,
    reconnect on close, JSON message parse.
12. **`data/hardware/paired_device_storage_test.dart`** —
    `SharedPreferences.setMockInitialValues`. Save / load / clear.
    Smallest hardware-layer test; should land first to establish the
    pattern.
13. **`integration/kgql_model_type_live_test.dart`,
    `kgql_model_repository_live_test.dart`,
    `schema_model_type_struct_live_test.dart`** — moved from
    `test/data/schema/`, tagged `integration`, gated on
    `RUN_NX_MAIN_INTEGRATION=true`. **Stop running them on every push.**
14. **`layering/no_features_in_data_test.dart`** — third layering
    rule: scan `lib/data/**` for `package:nexus_voice_assistant/features/`.
    Fail with a list of offenders. Closes the architectural loop.
15. **`features/schema_navigator/widgets/attribute_definitions_section_test.dart`**
    + **`relationships_section_test.dart`** — visible-vs-deleted
    filtering, edit dialog round-trip, `onDelete` callback wiring.
    These widgets carry real logic, not just layout.

## Principles to enforce

- **Mirror `lib/` exactly.** The test for
  `features/schema_navigator/model_type_form_view_model.dart` lives at
  `test/features/schema_navigator/model_type_form_view_model_test.dart`.
  Anything else is a bug.
- **Test at the lowest layer with logic.** Domain types in pure Dart
  tests; data mappers with no Flutter binding; view-models with a
  `ProviderContainer` and a fake repository; widgets with the smallest
  fake graph that pumps. A widget test should never need a mocked
  `GraphQLClient` or a real WebSocket — that means logic leaked from
  `data/` into the feature layer.
- **One source file → one test file**, named `<source_filename>_test.dart`.
- **The fake repositories are THE testing seam for features.**
  `FakeImageRepository`, `FakeBatteryRepository`,
  `FakeModelTypeWriteRepository`, plus the projected schema providers
  with overrides, let every feature test bypass `nx_db` / HTTP / BLE
  entirely.
- **No widget test imports `package:nx_db/...` (other than `auth.dart`).**
  Same rule as production code; the layering tests cover production but
  not tests, so reviewers must enforce it on test files manually.
- **Integration tests are for things only the live server can answer**:
  KGQL CRUD round-trips, image / battery HTTP shape, BLE pairing.
  Anything that can be answered with a fake repository does *not*
  belong there.
- **Goldens are opt-in per widget**, not per page initially. Start with
  stable, deterministic widgets (`message_bubble`, `model_type_tree_row`,
  `timeline_slider`). Page-level goldens accumulate maintenance cost;
  reach for them once a feature stabilises.
- **Hardware / BLE goldens are out-of-scope.** That code can only be
  exercised against a real necklace — keep it tagged `hardware` and
  manually run.
- **Shared mocking goes in `test/_support/`.** Today there is none;
  treat it as a real testing kit with the same code-review bar as
  `lib/`.

## Suggested execution order

Mapped 1:1 onto the migration order in `nx_main_reorg.md` so test
work lands in the same step as the code it covers. Each step keeps
`flutter test --exclude-tags=integration --exclude-tags=hardware`
green.

1. **Move the three live `test/data/schema/*_test.dart` into
   `test/integration/`** and tag them `integration`. Add
   `dart_test.yaml` with the `integration` tag. `flutter test` now
   passes offline. Costs nothing, unblocks everything.
2. **Create `test/_support/`** with `pump_app.dart`, `riverpod_helpers.dart`,
   `mock_graphql_client.dart`, `fake_schema_data.dart`,
   `fake_image_repository.dart`, `fake_battery_repository.dart`,
   `fake_model_type_write_repository.dart`. Pure plumbing — no code
   under test changes.
3. **Add `domain/` tests** as the domain types are stable today (BLE
   value types, image / battery entries, voice transcript, schema
   drafts). Pure Dart; quick wins.
4. **Add `data/schema/schema_entity_mappers_test.dart`** —
   highest-value data-layer test. Round-trip every type.
5. **Add `data/schema/kgql_model_type_repository_test.dart` (unit, mocked client)**
   alongside the moved live file. Same coverage of write paths but
   without the network.
6. **Add `features/schema_navigator/model_type_form_view_model_test.dart`** —
   biggest view-model gap. Use `FakeModelTypeWriteRepository` +
   overrides for the schema providers.
7. **Add `data/voice/voice_transcript_mapping_test.dart` + `notifier_test.dart`** —
   mapping is pure; notifier needs `FakeTranscriptService`.
8. **Add `data/images/image_service_test.dart` + `battery_chart_service_test.dart`** —
   `http: MockClient` fixtures.
9. **Add view-models for image / battery / hardware / voice
   (reorg step 9)** then their `_view_model_test.dart` siblings.
   Each view-model test lands in the same PR as the view-model.
10. **Add widget tests for the highest-risk pages** — start with
    `model_type_form_page`, `images_page`, `battery_page`. Use the
    fakes from step 2.
11. **Add `data/ble/bg_ble_client_test.dart`,
    `data/socket/bg_socket_client_test.dart`,
    `data/hardware/paired_device_storage_test.dart`,
    `data/watch/watch_bridge_service_test.dart`** as drivers stabilise.
    Hardest to test; do them after the rest of the fast suite is
    paying off.
12. **Add `layering/no_features_in_data_test.dart`** to close the
    architectural loop. The `nx_time` test is the template.
13. **Add `integration/images_battery_http_integration_test.dart`** —
    real image server, behind `RUN_NX_MAIN_HTTP_INTEGRATION=true`. The
    BLE smoke test stays manual.
14. **Add a few goldens** — `message_bubble`, `model_type_tree_row`,
    `timeline_slider`. Page-level goldens for `model_type_detail_page`
    and `images_page` come last, once the surface is stable.
15. **Update `dart_test.yaml` and `test/README.md`** with the new
    layout, tags, and run commands.

After this, `flutter test --exclude-tags=integration --exclude-tags=hardware`
runs the entire fast suite (domain → data → view-model → widget →
golden → layering), `RUN_NX_MAIN_INTEGRATION=true flutter test test/integration`
covers the live PGDB / HTTP, and
`RUN_NX_MAIN_BLE_INTEGRATION=true flutter test --tags=hardware`
covers the necklace. The structure matches `nx_time` 1:1, with the
extra `data/ble/`, `data/socket/`, `data/background/`, `data/hardware/`,
`data/watch/`, and `data/voice/` folders reflecting `nx_main`'s
hardware reality.
