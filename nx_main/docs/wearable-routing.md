# NX Main routing and maintenance

NX Main manages the Nexus database and device integrations. Its foreground chat
is an app conversation. The necklace and watch are distinct sources for the
shared personal assistant. This refactor does not introduce multiple-domain
reads/writes: each session still requires one explicitly selected positive domain.

## Where responsibilities live

Paths below are relative to `mobile/nx_main/lib`.

| Module | Owns | Must not own |
| --- | --- | --- |
| `application/sessions/agent_routes.dart` | App, necklace and watch agent/source policy | Socket or BLE I/O |
| `application/sessions/session_identity.dart` | Immutable backend/user/domain/app ownership | Credentials or default domains |
| `application/sessions/session_coordinator.dart` | Desired-session deduplication and switch ordering | Device protocol or widgets |
| `data/background/ambient_session_provider.dart` | Auth/provider composition for wearable sessions | Packet processing |
| `data/background/background_entrypoint.dart` | Native isolate entry points | Application routing policy |
| `data/background/background_runtime.dart` | Background composition, BLE lifecycle, scoped HTTP/GPS/telemetry, service events | Foreground UI |
| `data/background/background_service_client.dart` | Foreground facade and correlated command replies | BLE implementation or socket audio |
| `data/background/background_commands.dart` | Isolate command/result serialization | Hardware actions |
| `data/background/background_session_command.dart` | Validated session message across the isolate boundary | Domain inference |
| `application/devices/` | Typed internal device requests/results | Dynamic wire maps |
| `data/necklace/necklace_relay.dart` | NRF uplink turns, image forwarding, ACK scheduling, response delivery | Scanning, reconnect timing or characteristic writes |
| `data/necklace/necklace_audio_codec.dart` | Validated server audio to NRF framing and reception summaries | Network connection state |
| `data/necklace/necklace_device_protocol.dart` | Legacy control-frame recognition and reply dispatch | BLE writes |
| `data/necklace/necklace_command_handler.dart` | Device tool semantics and operation ordering | Authentication or transport lifecycle |
| `data/necklace/necklace_device_port.dart` | Narrow hardware interface and delegating BLE adapter | New BLE policy |
| `data/necklace/necklace_socket_port.dart` | Narrow transport interface used by the relay | Concrete websocket implementation |
| `data/socket/bg_socket_client.dart` | Necklace websocket auth, connection generation and packet queues | Device tool implementations |
| `data/ble/bg_ble_client.dart` | Proven BLE connection/characteristic/write behavior | Agent selection |
| `data/watch/watch_voice_relay.dart` | Watch audio conversion, turn scheduling, watch playback | Necklace packet framing |
| `data/voice/voice_socket_session.dart` | Shared app/watch voice session over `nx_voice` | Wearable capability selection |
| `features/voice/voice_socket_controller.dart` | Foreground recording/playback and UI state | Necklace socket forwarding |

`data/background/background_service.dart` is a compatibility export/type alias,
not another runtime. `main.dart` uses the dedicated entrypoint file.

## Routing contracts

- App: `X-Client-App=nx_main`, `X-Agent-Id=nx_main`, no device source.
- Necklace: `X-Client-App=nx_main`, `X-Agent-Id=personal_assistant`,
  `X-Device-Source=necklace`.
- Watch: `X-Client-App=nx_watch`, `X-Agent-Id=personal_assistant`,
  `X-Device-Source=nx_watch`.
- All three carry `X-Domain-Id`. No fallback domain exists.
- Session switches retire old sockets/queues; async completions are guarded by
  generation. Device results from retired sessions must not reach a new session.
- Necklace uplink preserves the original NRF bytes, including meta/EOF, inside
  the existing index wrapper. Do not replace this with the app/watch encoder.
- Only validated nonempty server audio and its matching EOF reach BLE. Text,
  progress and recognized device-control frames must never reach the Opus parser.
- ACKs remain immediate, unawaited writes. Camera recording sets the period
  before starting; a failed period write prevents the start command.

The BLE implementation, native WatchConnectivity bridge, firmware, server,
package dependencies, and transport retry/write timing were not changed.
The legacy unexposed `get_gps` control response is preserved in the protocol
adapter; replacing its placeholder behavior is a separate functional change.

## Validation and future edits

Run from `mobile/nx_main`:

```sh
flutter test test/application test/data/socket test/data/necklace test/data/watch test/data/ble test/data/background test/features/auth
flutter test
```

| Test | Purpose |
| --- | --- |
| `test/data/socket/wire_contract_test.dart` | Independent golden bytes, UTF-8 sizing, copied FIFO queue, request ID, stale device result suppression |
| `test/data/socket/audio_packet_filter_test.dart` | Real websocket reproduction of battery progress corrupting BLE audio |
| `test/data/socket/domain_socket_test.dart` | Positive domain, logout during auth, app/watch routing headers |
| `test/data/background/necklace_behavior_contract_test.dart` | Runtime wiring, nonblocking ACK, monotonic index/EOF, camera write order/failure, image/control separation |
| `test/data/background/background_commands_test.dart` | Isolate wire compatibility, typed payloads, malformed-input rejection |
| `test/data/background/background_service_client_contract_test.dart` | Immediate and mismatched replies, request correlation, camera status byte interpretation |
| `test/data/necklace/necklace_audio_codec_test.dart` | EOF ownership/reset, exact lengths, buffer offsets, turn summaries |
| `test/application/sessions/session_coordinator_test.dart` | Session identity, switching/deduplication, route policy, missing-domain rejection |
| `test/data/watch/watch_voice_relay_test.dart` | Watch resampling, Opus conversion, EOF, text handling |
| `test/features/auth/ios_auth_navigation_test.dart` | Existing iOS callback/navigation behavior |

Golden packet expectations are intentionally independent of production encoders.
If a test fails, determine which ownership/order/protocol requirement changed.
Do not update expected bytes, remove assertions, or introduce default domains
just to make a refactor pass. A deliberate wire change needs corresponding
server/firmware changes and an explicit compatibility decision.

## Staged verification record

1. Added network and background behavior contracts before extraction: 21 pass.
2. Extracted codec, device port and command handler: the same 21 pass.
3. Extracted relay: the same 21 pass.
4. Split foreground/runtime and typed commands: 25 pass.
5. Centralized sessions/routes and checked iOS auth: 32 pass.
6. Removed verified unused legacy voice page/view-model, audio manager, interaction
   manager and MCP helper; removed obsolete foreground-text-to-necklace events:
   32 pass. The deleted view-model's sole test only mirrored transcript state;
   the existing active transcript notifier tests continue to cover that behavior.
7. Additional boundary review tests cover codec resets, foreground replies and
   stale reconnect completions: 40 focused tests pass. Targeted static analysis
   reports no issues. Full suite: 108 pass, 3 live tests skipped, the same 3
   pre-existing failures remain. The BLE implementation was compared with HEAD
   and is byte-for-byte unchanged.

The full baseline was already failing in three places before this work:
`images_battery_http_integration_test.dart` omits required `httpClient`,
`no_flutter_in_domain_test.dart` detects a schema query importing `nx_db`, and
`no_nx_db_in_features_test.dart` detects log UI imports of `nx_db`.
These unrelated failures are not suppressed or reclassified. Live service and
physical-device behavior require a separate smoke test; unit tests cannot prove
radio timing or playback on a sleeping device.

## Device verification

Shorebird patch 4 was published for iOS release `1.0.21+20260927`. The
iPhone updater confirmed `last_booted_patch=4` with no boot pending. The user
then tested the updated NX Main app and confirmed it worked.
