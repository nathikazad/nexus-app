# `nx_main` reorganization plan

Make `nx_main` (the Nexus Voice Assistant — BLE necklace + voice + schema
navigator) look like `nx_time`. Same four layers, same naming, same test
layout. See [`mobile/nx_time/docs/arch.md`](../../../nx_time/docs/arch.md) and
[`nx_time_reorg.md`](../../../nx_time/plans/current_plan/nx_time_reorg.md) for
the prototype, and
[`mobile/nx_expense/plans/current/nx_expense_reorg.md`](../../../nx_expense/plans/current/nx_expense_reorg.md)
for a parallel app reorg.

`nx_main` differs from `nx_time` / `nx_expense` in two ways:

- It owns **hardware** (BLE, audio, RTC, camera, watch bridge) and a
  **background isolate** (`flutter_background_service`).
- It owns the **schema navigator** UI (model types, attributes, relations) —
  the only Flutter app today that lets a user CRUD `ModelType` rows.

Both fit the four-layer model: hardware/IO drivers live in `data/` (or a
peer `services/` that obeys the same rules); schema-navigator screens are
just another `features/` slice.

## Layer rules

```
lib/
  core/        generic, app-agnostic, Flutter-only utilities
  domain/      PURE DART — typed entities + abstract repository interfaces
  data/        bridges domain ⇄ nx_db / device / network; KGQL + Riverpod here
  features/    screens, view-models, feature-local providers and widgets
```

| Layer | May import | Must NOT import |
|-------|------------|-----------------|
| `core/` | `flutter`, `intl`, pure Dart | `domain/`, `data/`, `features/`, any `package:nx_db/*` |
| `domain/` | pure Dart only | Flutter, Riverpod, `nx_db`, BLE / sockets / I/O |
| `data/` | `core/`, `domain/`, `flutter_riverpod`, `graphql_flutter`, `flutter_blue_plus`, `web_socket_channel`, `package:nx_db/{auth,kgql,riverpod}.dart` | `features/` |
| `features/` | below + `package:nx_db/auth.dart` ONLY | `package:nx_db/{nx_db,kgql,riverpod,internal}.dart`, `package:nx_db/src/...`, `graphql_flutter`, `flutter_blue_plus`, `web_socket_channel` |

Two layering tests in `test/layering/` enforce the bottom two rows.

## Target `lib/` blueprint

```
nx_main/
  lib/
    main.dart                       # ProviderScope + runApp + bg service init
    app.dart                        # MaterialApp.router + theme
    router.dart                     # GoRouter; appBootstrapProvider + appStatus

    core/
      theme/
        app_theme.dart              # was lib/app_theme.dart
      layout/
        layout.dart                 # was lib/layout.dart
      logging/
        logging_service.dart        # was lib/services/logging_service.dart
        log_entry.dart              # was lib/models/log_entry.dart
      audio/
        audio_stream_manager.dart   # was lib/widgets/audio_stream_manager.dart
                                    # (no UI — generic audio playback)
      widgets/
        loading_indicator.dart      # was lib/widgets/loading_indicator.dart
        error_widget.dart           # was lib/widgets/error_widget.dart
        timeline_slider.dart        # was lib/screens/widgets/timeline_slider.dart
        attribute_field.dart        # was lib/widgets/attribute_field.dart
        message_bubble.dart         # was lib/widgets/message_bubble.dart
        input_area.dart             # was lib/widgets/input_area.dart
        expanding_fab_menu.dart     # was lib/widgets/expanding_fab_menu.dart

    domain/                         # PURE DART
      ble/
        ble_connection_state.dart   # enum (idle/scanning/connecting/connected)
        ble_constants.dart          # UUIDs (no flutter_blue_plus)
        battery_data.dart           # BatteryData value type
        camera_record_status.dart
      device/
        paired_device.dart          # value type for the saved pairing
      images/
        image_entry.dart            # value type for one image
        image_repository.dart       # abstract: list days, list for day
      battery/
        battery_point.dart          # one battery sample (HH:MM:SS, %, mV, charging)
        battery_repository.dart     # abstract: available days, points for day
      ai/
        interaction.dart            # was lib/services/ai_service/interaction.dart
        interaction_manager.dart    # pure Dart stream owner
      schema/                       # navigator domain (admin)
        model_type_form_state.dart  # pure form state used by view-model
        attribute_definition_draft.dart
        relation_definition_draft.dart

    data/
      providers.dart                # binds repositories + services to Riverpod;
                                    # builds repos from Ref; only file that
                                    # composes deps
      ble/
        bg_ble_client.dart          # was lib/bg_ble_client.dart
      socket/
        bg_socket_client.dart       # was lib/bg_socket_client.dart (WebSocket; not BLE)
      background/
        background_service.dart     # was lib/background_service.dart
                                    # (orchestrates BLE + socket in bg isolate)
      hardware/
        hardware_service.dart       # was services/hardware_service/hardware_service.dart
        camera_command.dart         # was services/hardware_service/camera_command.dart
        rtc_service.dart            # was services/hardware_service/rtc_service.dart
        paired_device_storage.dart  # was services/paired_device_storage.dart
      watch/
        watch_bridge_service.dart   # was services/watch_bridge_service.dart
      images/
        image_service.dart          # was services/image_service.dart (HTTP)
        image_repository.dart       # implements domain ImageRepository
      battery/
        battery_chart_service.dart  # was services/battery_chart_service.dart
        battery_repository.dart     # implements domain BatteryRepository
      ai/
        agent_tool_service.dart     # was services/ai_service/agent_tool_service.dart (MCP)
      schema/                       # navigator data (KGQL admin)
        model_type_attr_keys.dart   # any string keys used by KGQL admin
        kgql_model_type_repository.dart  # set/get model types via setKgqlModelTypes
        kgql_model_repository.dart  # CRUD for Model rows
        model_type_struct.dart      # struct builder for navigator queries

    features/
      auth/
        login_page.dart             # was screens/login_page.dart
      splash/
        splash_page.dart            # was screens/splash_page.dart
      home/
        home_page.dart              # was screens/home_screen.dart (bottom-nav shell)
      voice/
        voice_assistant_page.dart   # was screens/voice_assistant_screen.dart
        voice_assistant_view_model.dart   # transcript stream + state
      hardware/
        hardware_page.dart          # was screens/hardware_screen.dart
        hardware_view_model.dart    # battery / RTC / camera / haptic state
        device_selection_page.dart  # was screens/device_selection_screen.dart
        widgets/
          camera_section.dart       # was widgets/camera_section.dart
      data_browser/
        data_page.dart              # was screens/data_screen.dart
        images_page.dart            # was screens/images_screen.dart
        images_view_model.dart
        battery_page.dart           # was screens/battery_screen.dart
        battery_view_model.dart
      logs/
        log_viewer_page.dart        # was screens/log_viewer_screen.dart
      schema_navigator/             # the model-type / model admin
        models_page.dart            # was screens/models_screen.dart
        model_type_selector_page.dart
        model_type_detail_page.dart
        model_type_form_page.dart
        model_type_form_view_model.dart   # was navigator/model_type_form_controller.dart
        models_list_page.dart
        model_detail_page.dart
        model_form_page.dart
        relationship_form_page.dart
        widgets/
          model_type_row.dart       # was navigator/widgets/model_type_row.dart
          model_row.dart            # was widgets/model_row.dart
          relationships_section.dart
          model_type_basic_fields.dart
          attribute_definitions_section.dart
```

Notes:

- `lib/main_ble.dart` is a commented-out legacy file — delete during the move.
- `services/` is dissolved: hardware/IO drivers move to `data/<area>/`, pure
  helpers (logging, audio playback) move to `core/`, AI conversation state
  (`Interaction`, `InteractionManager`) is pure Dart → `domain/ai/`.
- `widgets/` is split: feature-specific into `features/<area>/widgets/`,
  generic into `core/widgets/`.
- `screens/widgets/` (today only `timeline_slider.dart`) folds into
  `core/widgets/`.

## Target `test/` blueprint

Mirrors `lib/`, one test file per source file (today only three KGQL tests
live under `test/`).

```
nx_main/test/
  _support/
    pump_app.dart
    riverpod_helpers.dart
    mock_graphql_client.dart
    fake_ble_client.dart
    fake_socket_client.dart
    fake_image_repository.dart
    fake_battery_repository.dart
    integration_auth.dart

  core/
    logging/logging_service_test.dart
    audio/audio_stream_manager_test.dart

  domain/
    ble/{ble_connection_state_test.dart, battery_data_test.dart}
    images/image_entry_test.dart
    battery/battery_point_test.dart
    ai/{interaction_test.dart, interaction_manager_test.dart}
    schema/model_type_form_state_test.dart

  data/
    providers_test.dart
    ble/
      bg_ble_client_test.dart
    socket/
      bg_socket_client_test.dart
    background/
      background_service_test.dart
    hardware/
      hardware_service_test.dart
      rtc_service_test.dart
      paired_device_storage_test.dart
    images/{image_service_test.dart, image_repository_test.dart}
    battery/{battery_chart_service_test.dart, battery_repository_test.dart}
    ai/agent_tool_service_test.dart
    schema/
      kgql_model_type_repository_test.dart   # was test/set_model_type_test.dart
      kgql_model_repository_test.dart        # was test/set_model_test.dart
      model_type_struct_test.dart            # was test/get_model_type_test.dart

  features/
    voice/voice_assistant_view_model_test.dart
    hardware/hardware_view_model_test.dart
    data_browser/{images_view_model_test.dart, battery_view_model_test.dart}
    schema_navigator/model_type_form_view_model_test.dart

  widget/
    splash_page_test.dart
    login_page_test.dart
    home_page_test.dart

  layering/
    no_flutter_in_domain_test.dart
    no_nx_db_in_features_test.dart

  integration/
    kgql_model_type_live_test.dart            # was test/data/schema/kgql_model_type_repository_test.dart
    kgql_model_repository_live_test.dart
    schema_model_type_struct_live_test.dart   # RUN_NX_MAIN_INTEGRATION=true
```

## File-by-file move map

| Today's path | New path |
|--------------|----------|
| `lib/main.dart` | `lib/main.dart` (split: `app.dart` for `MaterialApp.router`) |
| `lib/router.dart` | `lib/router.dart` |
| `lib/main_ble.dart` | **delete** (commented-out legacy) |
| `lib/app_theme.dart` | `lib/core/theme/app_theme.dart` |
| `lib/layout.dart` | `lib/core/layout/layout.dart` |
| `lib/models/log_entry.dart` | `lib/core/logging/log_entry.dart` |
| `lib/services/logging_service.dart` | `lib/core/logging/logging_service.dart` |
| `lib/widgets/audio_stream_manager.dart` | `lib/core/audio/audio_stream_manager.dart` |
| `lib/widgets/loading_indicator.dart` | `lib/core/widgets/loading_indicator.dart` |
| `lib/widgets/error_widget.dart` | `lib/core/widgets/error_widget.dart` |
| `lib/widgets/attribute_field.dart` | `lib/core/widgets/attribute_field.dart` |
| `lib/widgets/message_bubble.dart` | `lib/core/widgets/message_bubble.dart` |
| `lib/widgets/input_area.dart` | `lib/core/widgets/input_area.dart` |
| `lib/widgets/expanding_fab_menu.dart` | `lib/core/widgets/expanding_fab_menu.dart` |
| `lib/screens/widgets/timeline_slider.dart` | `lib/core/widgets/timeline_slider.dart` |
| `lib/services/ai_service/interaction.dart` | `lib/domain/ai/interaction.dart` + `lib/domain/ai/interaction_manager.dart` |
| `lib/bg_ble_client.dart` | `lib/data/ble/bg_ble_client.dart` (extract `BleConstants`, `BleConnectionState`, `BatteryData` to `domain/ble/`) |
| `lib/bg_socket_client.dart` | `lib/data/socket/bg_socket_client.dart` |
| `lib/background_service.dart` | `lib/data/background/background_service.dart` |
| `lib/services/hardware_service/hardware_service.dart` | `lib/data/hardware/hardware_service.dart` |
| `lib/services/hardware_service/camera_command.dart` | `lib/data/hardware/camera_command.dart` |
| `lib/services/hardware_service/rtc_service.dart` | `lib/data/hardware/rtc_service.dart` |
| `lib/services/paired_device_storage.dart` | `lib/data/hardware/paired_device_storage.dart` |
| `lib/services/watch_bridge_service.dart` | `lib/data/watch/watch_bridge_service.dart` |
| `lib/services/image_service.dart` | `lib/data/images/image_service.dart` (+ `image_repository.dart` impl) |
| `lib/services/battery_chart_service.dart` | `lib/data/battery/battery_chart_service.dart` (+ `battery_repository.dart` impl) |
| `lib/services/ai_service/agent_tool_service.dart` | `lib/data/ai/agent_tool_service.dart` |
| `lib/screens/login_page.dart` | `lib/features/auth/login_page.dart` |
| `lib/screens/splash_page.dart` | `lib/features/splash/splash_page.dart` |
| `lib/screens/home_screen.dart` | `lib/features/home/home_page.dart` |
| `lib/screens/voice_assistant_screen.dart` | `lib/features/voice/voice_assistant_page.dart` (+ `_view_model.dart`) |
| `lib/screens/hardware_screen.dart` | `lib/features/hardware/hardware_page.dart` (+ `_view_model.dart`) |
| `lib/screens/device_selection_screen.dart` | `lib/features/hardware/device_selection_page.dart` |
| `lib/widgets/camera_section.dart` | `lib/features/hardware/widgets/camera_section.dart` |
| `lib/screens/data_screen.dart` | `lib/features/data_browser/data_page.dart` |
| `lib/screens/images_screen.dart` | `lib/features/data_browser/images_page.dart` (+ `_view_model.dart`) |
| `lib/screens/battery_screen.dart` | `lib/features/data_browser/battery_page.dart` (+ `_view_model.dart`) |
| `lib/screens/log_viewer_screen.dart` | `lib/features/logs/log_viewer_page.dart` |
| `lib/screens/models_screen.dart` | `lib/features/schema_navigator/models_page.dart` |
| `lib/screens/navigator/*.dart` | `lib/features/schema_navigator/*_page.dart` |
| `lib/screens/navigator/model_type_form_controller.dart` | split: form-state types → `lib/domain/schema/`; controller → `lib/features/schema_navigator/model_type_form_view_model.dart`; KGQL `set` mutation → `lib/data/schema/kgql_model_type_repository.dart` |
| `lib/screens/navigator/widgets/*.dart` | `lib/features/schema_navigator/widgets/*.dart` |
| `lib/widgets/model_row.dart` | `lib/features/schema_navigator/widgets/model_row.dart` |
| `lib/widgets/model_type_row.dart` | `lib/features/schema_navigator/widgets/model_type_row.dart` (consolidate with `screens/navigator/widgets/model_type_row.dart`) |

## Conventions

1. `<feature>_page.dart` + `<feature>_view_model.dart` per screen.
2. `domain/` is pure Dart — no `flutter_blue_plus`, no `web_socket_channel`,
   no `package:nx_db/...` (except value-shaped re-exports if any).
3. **Hardware drivers (BLE, sockets, RTC, watch bridge, AI MCP, image / battery
   HTTP) live in `data/`.** They take dependencies in their constructors and
   are wired in `data/providers.dart`. No `Ref` inside the driver.
4. The **background isolate** (`background_service.dart`) lives in
   `data/background/` and orchestrates the BLE client (`data/ble/`) and the
   WebSocket client (`data/socket/`) — it is not BLE-specific. Its entry-point
   closures (`onStart`, `onIosBackground`) stay in `lib/main.dart` so the
   isolate registry can find them at top level — but the implementation they
   call (`BleBackgroundService.startBackgroundService`) lives in
   `data/background/background_service.dart`.
5. **`features/` only consumes domain types.** Hardware screens watch
   `hardwareViewModelProvider`, not `hardwareServiceProvider` directly.
   Schema-navigator screens depend on `domain/schema/*` form-state types and
   call `data/schema/*` repositories via providers.
6. Attribute key strings (when KGQL `Model` rows are used in the navigator)
   live in `data/schema/<x>_attr_keys.dart`. Mappers are pure functions.
7. `features/` may import `package:nx_db/auth.dart` only. No `nx_db.dart`,
   no `kgql.dart`, no `riverpod.dart`, no `nx_db/src/...`.
8. Tests mirror `lib/` paths; layering tests in `test/layering/` are
   non-negotiable.

## Migration order

1. **Create `core/`**: move `app_theme.dart`, `layout.dart`, `logging_service`
   + `log_entry`, `audio_stream_manager`, generic widgets, and
   `screens/widgets/timeline_slider.dart`. Pure rename + import update.
2. **Create `domain/ai/`**: move `services/ai_service/interaction.dart` (it is
   already pure Dart); split into `interaction.dart` and
   `interaction_manager.dart` if useful.
3. **Create `domain/ble/`**: extract value types from `bg_ble_client.dart`
   (`BleConnectionState`, `BleConstants`, `BatteryData`, `CameraRecordStatus`)
   into pure-Dart files. Keep BLE driver in place; only move the value types.
4. **Create `domain/images/` and `domain/battery/`**: extract `ImageEntry`,
   `BatteryPoint`, and define abstract `*Repository` interfaces.
5. **Create `data/`** and move drivers:
   - BLE client → `data/ble/`
   - WebSocket client → `data/socket/`
   - Background-isolate orchestrator → `data/background/`
   - Hardware services (RTC, camera, paired-device storage, `HardwareService`)
     → `data/hardware/`
   - Watch bridge → `data/watch/`
   - HTTP services (`image_service.dart`, `battery_chart_service.dart`,
     `agent_tool_service.dart`) → `data/<area>/`

   Implement the new domain `*Repository` interfaces in `data/`.
6. **Add `data/providers.dart`** — the only place that builds repositories /
   services from `Ref`. Update existing `bleBackgroundServiceProvider`,
   `hardwareServiceProvider`, etc. to live here.
7. **Schema navigator**: split
   `screens/navigator/model_type_form_controller.dart` into
   `domain/schema/model_type_form_state.dart` (pure state),
   `data/schema/kgql_model_type_repository.dart` (the
   `setKgqlModelTypes` mutation), and
   `features/schema_navigator/model_type_form_view_model.dart` (the
   `Notifier`). Move existing `test/{set_model_test, set_model_type_test,
   get_model_type_test}.dart` under `test/data/schema/`.
8. **Rename `screens/` → `features/`** with one folder per area
   (`auth/`, `splash/`, `home/`, `voice/`, `hardware/`, `data_browser/`,
   `logs/`, `schema_navigator/`); nest local widgets under
   `features/<area>/widgets/`.
9. **Add view-models** for screens that today hold logic in `State` classes:
   `voice_assistant`, `hardware`, `images`, `battery`,
   `model_type_form` (already a `Notifier` — just rename + relocate).
10. **Strip KGQL from `features/`**: replace `package:nx_db/nx_db.dart`
    imports with `package:nx_db/auth.dart` and surface domain types through
    view-models. Keep `User`, `BackendPreset`, `authProvider`,
    `appStatusProvider` usage — those are `auth.dart`.
11. **Mirror `test/` to `lib/`** and add the two `layering/` tests from
    `nx_time`. Move existing `test/{set_model, set_model_type, get_model_type}_test.dart`
    into `test/data/schema/`.
12. **Optional**: split `main.dart` into `main.dart` + `app.dart` for parity
    with `nx_time` and `nx_expense`. Top-level `onStart` / `onIosBackground`
    closures must remain in `main.dart` for the background-service entry-point
    registry.

After step 12 the layout, naming, and test placement match `nx_time` 1:1.
Hardware and schema-navigator code is reachable from `features/` only through
domain interfaces, so swapping a fake BLE / socket / repository in tests is
the same `ProviderScope.overrides` move used in `nx_time`.
