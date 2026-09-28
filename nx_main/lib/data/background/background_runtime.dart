import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:http/http.dart' as http;
import 'package:nexus_voice_assistant/data/ble/bg_ble_client.dart'
    show BleClient;
import 'package:nexus_voice_assistant/data/gps/gps_upload_manager.dart';
import 'package:nexus_voice_assistant/data/socket/bg_socket_client.dart';
import 'package:nexus_voice_assistant/data/telemetry/telemetry_upload_manager.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_observability/nx_observability.dart';
import '../../application/devices/device_command.dart';
import '../../application/devices/device_command_result.dart';
import '../../application/sessions/agent_routes.dart';
import '../necklace/necklace_device_port.dart';
import '../necklace/necklace_relay.dart';
import 'background_commands.dart';
import 'background_session_command.dart';
import 'ambient_storage_domain.dart';
import '../devices/necklace_identity.dart';
import '../devices/necklace_enrollment.dart';

class BackgroundRuntime {
  /// Start the background service (called from onStart entry point)
  static Future<void> start(
    ServiceInstance service, {
    BleClient? device,
    SocketClient? socket,
    bool initializePlugins = true,
    bool maintenanceTick = true,
  }) async {
    if (initializePlugins) {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
    }

    // ============================================================================
    // 1. INITIALIZATION
    // ============================================================================

    final bleClient = device ?? BleClient();
    final socketClient = socket ?? SocketClient();
    TelemetryUploadManager? telemetryUploadManager;
    GpsUploadManager? gpsUploadManager;
    http.Client? authenticatedHttpClient;
    int sessionGeneration = 0;
    NecklaceDeviceAuth? deviceAuth;
    bool pairingDevice = false;
    Map<String, dynamic>? lastSocketConfig;
    Future<void> Function(Map<String, dynamic>)? reconnect;

    final relay = NecklaceRelay(
      device: BleNecklaceDevicePort(bleClient),
      socketClient: socketClient,
      emit: service.invoke,
      currentGeneration: () => sessionGeneration,
    );
    bool appIsForeground = true;
    String? gpsHttpBaseUrl;
    String? gpsTimezoneLabel;

    Future<void> retireSession() async {
      deviceAuth?.close();
      deviceAuth = null;
      final gps = gpsUploadManager;
      final client = authenticatedHttpClient;
      gpsUploadManager = null;
      telemetryUploadManager = null;
      authenticatedHttpClient = null;
      gpsHttpBaseUrl = null;
      gpsTimezoneLabel = null;
      final disconnected = socketClient.disconnect();
      client?.close();
      await gps?.stop(flushPending: false);
      await disconnected;
    }

    // ============================================================================
    // 2. BLE CONFIGURATION
    // ============================================================================

    Future<void> printServerClockDrift(
      String httpBaseUrl,
      http.Client client,
    ) async {
      final base = httpBaseUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/time');
      final localSend = DateTime.now().toUtc();
      final sw = Stopwatch()..start();
      try {
        final response =
            await client.get(uri).timeout(const Duration(seconds: 5));
        final localReceive = DateTime.now().toUtc();
        sw.stop();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          debugPrint(
            '[Clock Sync] GET /time failed: ${response.statusCode} ${response.body}',
          );
          return;
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          debugPrint('[Clock Sync] GET /time returned invalid JSON');
          return;
        }
        final serverUnixUs = decoded['unix_us'];
        if (serverUnixUs is! int) {
          debugPrint('[Clock Sync] GET /time missing unix_us: $decoded');
          return;
        }
        final rttUs = localReceive.difference(localSend).inMicroseconds;
        final estimatedServerAtReceive = DateTime.fromMicrosecondsSinceEpoch(
          serverUnixUs + (rttUs ~/ 2),
          isUtc: true,
        );
        final offsetMs =
            estimatedServerAtReceive.difference(localReceive).inMicroseconds /
                1000.0;
        debugPrint(
          '[Clock Sync] local_send=${localSend.toIso8601String()} '
          'server=${decoded['time']} '
          'local_receive=${localReceive.toIso8601String()} '
          'rtt_ms=${(sw.elapsedMicroseconds / 1000.0).toStringAsFixed(3)} '
          'estimated_offset_ms=${offsetMs.toStringAsFixed(3)}',
        );
      } catch (e) {
        sw.stop();
        debugPrint('[Clock Sync] GET /time error: $e');
      }
    }

    Future<void> startGpsIfBackground(String reason) async {
      if (appIsForeground) {
        debugPrint('[GPS Upload] not starting in foreground reason=$reason');
        return;
      }
      final base = gpsHttpBaseUrl;
      final client = authenticatedHttpClient;
      if (base == null || base.isEmpty || client == null) {
        debugPrint('[GPS Upload] not starting: missing upload session');
        return;
      }
      gpsUploadManager ??= GpsUploadManager(
        httpBaseUrl: base,
        client: client,
        flushInterval: const Duration(minutes: 10),
        timezoneLabel: gpsTimezoneLabel,
      );
      if (gpsUploadManager!.isRunning) {
        debugPrint('[GPS Upload] already running reason=$reason');
        return;
      }
      debugPrint('[GPS Upload] starting for background reason=$reason');
      gpsUploadManager!.start();
    }

    Future<void> stopGpsForForeground(String reason) async {
      final manager = gpsUploadManager;
      if (manager == null || !manager.isRunning) {
        debugPrint('[GPS Upload] already stopped in foreground reason=$reason');
        return;
      }
      debugPrint('[GPS Upload] stopping for foreground reason=$reason');
      await manager.stop(flushPending: true);
    }

    bleClient.onConnectionStateChanged = (state) {
      debugPrint("[BLE BG] Connection state: ${state.name}");
      service.invoke('ble.status', {'status': state.name});
      if (state.name == 'connected') {
        if (lastSocketConfig != null)
          unawaited(reconnect?.call(lastSocketConfig!) ?? Future.value());
      } else {
        ++sessionGeneration;
        unawaited(retireSession());
      }
    };

    bleClient.onAudioPacketReceived = relay.onAudioPacket;

    bleClient.onError = (error) {
      debugPrint("[BLE BG] Error: $error");
      service.invoke('ble.error', {'error': error});
    };

    bleClient.onCameraStatusReceived = (isRecording, periodSec) {
      service.invoke('device.push', {
        'type': 'camera',
        'data': {'isRecording': isRecording, 'periodSec': periodSec},
      });
    };

    bleClient.onBatteryReceived = (data) {
      final parsed = BleClient.parseBatteryStatus(data);
      if (parsed == null) return;
      final (:voltageMv, :percent, :charging, :timeIso, :timezone) = parsed;
      final push = <String, dynamic>{
        'type': 'battery',
        'percent': percent,
        'voltageMv': voltageMv,
        'charging': charging,
      };
      if (timeIso != null) push['time'] = timeIso;
      if (timezone != null) push['timezone'] = timezone;
      service.invoke('device.push', push);
      socketClient.sendText(jsonEncode(push));
    };

    await bleClient.initialize();

    // ============================================================================
    // 3. SOCKET CONFIGURATION
    // ============================================================================

    relay.attachSocket();

    // ============================================================================
    // 4. SERVICE EVENT HANDLERS
    // ============================================================================

    // BLE control events
    service.on('ble.start').listen((event) async {
      await bleClient.scanAndConnect();
    });

    service.on('ble.applyPairedRemoteId').listen((event) async {
      final id = event?['remoteId'] as String?;
      if (id == null || id.isEmpty) return;
      bleClient.setPreferredRemoteId(id);
      await bleClient.scanAndConnect(overrideRemoteId: id);
    });

    service.on('ble.clearPairedRemoteId').listen((event) async {
      bleClient.setPreferredRemoteId(null);
      await bleClient.disconnect(intentional: true);
    });

    service.on('ble.syncStatus').listen((event) {
      service.invoke('ble.status', {'status': bleClient.state.name});
    });

    service.on('ble.stop').listen((event) async {
      await bleClient.disconnect(intentional: true);
    });

    // Socket control events
    Future<void> connectSession(Map<String, dynamic> event) async {
      final generation = ++sessionGeneration;
      await retireSession();
      if (generation != sessionGeneration) return;
      late BackgroundSessionCommand command;
      try {
        command = BackgroundSessionCommand.fromMap(event);
      } catch (_) {
        debugPrint('[Socket] Ignoring connect without complete auth session');
        return;
      }
      if (pairingDevice || !bleClient.isConnected) return;
      final remoteId = bleClient.device?.remoteId.str;
      if (remoteId == null) return;
      final enrolledId = await NecklaceEnrollment.load(
          command.preset.key, command.userId, remoteId);
      if (generation != sessionGeneration) return;
      if (enrolledId == null) {
        service.invoke('ble.error',
            {'error': 'Add Necklace in Devices to link it to your account.'});
        return;
      }
      final url = command.url;
      final userId = command.userId;
      final preset = command.preset;
      final clientAppId = command.clientAppId;
      final telemetryHttpBaseUrl = command.telemetryHttpBaseUrl;

      final uploadBase = telemetryHttpBaseUrl.isNotEmpty
          ? telemetryHttpBaseUrl
          : httpBaseFromSocketUrl(url);
      final auth = NecklaceDeviceAuth(
        baseUrl: uploadBase,
        deviceId: enrolledId,
        exchange: bleClient.exchangeIdentity,
        isCurrent: () =>
            generation == sessionGeneration &&
            bleClient.isConnected &&
            bleClient.device?.remoteId.str == remoteId,
      );
      deviceAuth = auth;
      final socketMetadata = AgentRoutes.necklace.ambientHeaders();
      await socketClient.connect(url,
          headers: socketMetadata, authHeaders: auth.headers);
      if (generation != sessionGeneration) return;

      // User authentication belongs to phone telemetry/GPS, not Necklace's socket.
      final oidc = NexusOidcService();
      if (preset.requiresOidc) {
        final identity = await oidc.restore(preset, clientAppId);
        if (generation != sessionGeneration) return;
        if (identity == null || identity.userId != userId) {
          debugPrint('[Socket] Background auth session is unavailable');
          return;
        }
      }
      Future<Map<String, String>> authHeaders(bool forceRefresh) async {
        if (!preset.requiresOidc) {
          return nexusAuthHeaders(preset, userId);
        }
        final token = await oidc.accessToken(forceRefresh: forceRefresh);
        return {'authorization': 'Bearer $token'};
      }

      late int storageDomainId;
      try {
        storageDomainId = await loadAmbientStorageDomain(
            httpBaseUrl: uploadBase, authHeaders: authHeaders);
      } catch (error) {
        debugPrint('[Socket] Personal storage lookup failed: $error');
        return;
      }
      if (generation != sessionGeneration) return;

      final client = NexusAuthenticatedClient(
        preset: preset,
        userId: userId,
        domainId: storageDomainId,
        authHeaders: authHeaders,
      );
      authenticatedHttpClient = client;
      unawaited(printServerClockDrift(uploadBase, client));
      telemetryUploadManager = TelemetryUploadManager(
        httpBaseUrl: uploadBase,
        client: client,
        onCommitted: (transferId) async {
          await bleClient.writeFileRx(telemetryCommittedAck(transferId));
          debugPrint('Telemetry upload committed transfer=$transferId');
        },
      );
      gpsHttpBaseUrl = uploadBase;
      gpsTimezoneLabel = localTimezoneOffsetLabel();
      await startGpsIfBackground('socket.connect');
      if (generation != sessionGeneration) return;
    }

    reconnect = connectSession;
    service.on('socket.connect').listen((event) async {
      if (event == null) return;
      lastSocketConfig = event;
      await connectSession(event);
    });
    service.on('device.pairing').listen((event) async {
      pairingDevice = event?['active'] == true;
      if (pairingDevice) {
        ++sessionGeneration;
        await retireSession();
      } else if (lastSocketConfig != null) {
        await connectSession(lastSocketConfig!);
      }
    });
    service.on('device.enrolled').listen((_) async {
      if (lastSocketConfig != null) await connectSession(lastSocketConfig!);
    });

    service.on('socket.disconnect').listen((event) async {
      lastSocketConfig = null;
      ++sessionGeneration;
      await retireSession();
    });

    service.on('gps.flush').listen((event) async {
      final ok = await gpsUploadManager?.flush();
      debugPrint('[GPS Upload] foreground flush requested ok=${ok ?? true}');
    });

    service.on('app.lifecycle').listen((event) async {
      final state = event?['state'] as String?;
      debugPrint('[GPS Upload] app lifecycle state=$state');
      switch (state) {
        case 'resumed':
        case 'inactive':
          appIsForeground = true;
          unawaited(socketClient.ensureConnected(reason: 'foreground'));
          await stopGpsForForeground(state ?? 'foreground');
          break;
        case 'paused':
        case 'hidden':
        case 'detached':
          appIsForeground = false;
          await startGpsIfBackground(state ?? 'background');
          break;
        default:
          break;
      }
    });

    // Service lifecycle events
    service.on('stop').listen((event) async {
      await gpsUploadManager?.stop(flushPending: true);
      gpsUploadManager = null;
      gpsHttpBaseUrl = null;
      gpsTimezoneLabel = null;
      await bleClient.disconnect(intentional: true);
      await socketClient.disconnect();
      authenticatedHttpClient?.close();
      authenticatedHttpClient = null;
      service.stopSelf();
    });

    // Unified BLE command handler
    service.on('ble.command').listen((event) async {
      late int requestId;
      late DeviceCommand request;
      try {
        (requestId, request) = BackgroundCommands.decode(event!);
      } catch (_) {
        service.invoke('ble.command.result', {
          'command': event?['command'],
          'requestId': event?['requestId'],
          'success': false,
          'error': 'Invalid device command',
        });
        return;
      }
      void sendResult(
          {required bool success,
          List<int>? bytes,
          String? text,
          String? error}) {
        service.invoke(
            'ble.command.result',
            BackgroundCommands.encodeResult(DeviceCommandResult(
                kind: request.kind,
                requestId: requestId,
                success: success,
                bytes: bytes,
                text: text,
                error: error)));
      }

      try {
        switch (request.kind) {
          case DeviceCommandKind.identityExchange:
            if (request.name == null ||
                bleClient.device?.remoteId.str != request.name) {
              throw StateError('Selected Necklace changed');
            }
            final bytes = await bleClient
                .exchangeIdentity(Uint8List.fromList(request.bytes ?? []));
            sendResult(success: true, bytes: bytes.toList());
            break;
          case DeviceCommandKind.writeHaptic:
            final effectId = request.effectId ?? 16;
            final success = await bleClient.writeHaptic(effectId);
            sendResult(success: success);
            break;
          case DeviceCommandKind.writeCamera:
            final rawData = request.bytes;
            if (rawData == null || rawData.isEmpty) {
              sendResult(success: false);
              return;
            }
            final success = await bleClient
                .writeCamera(Uint8List.fromList(List<int>.from(rawData)));
            sendResult(success: success);
            break;
          case DeviceCommandKind.readBattery:
            final batteryData = await bleClient.readBattery();
            sendResult(
                success: batteryData != null, bytes: batteryData?.toList());
            break;
          case DeviceCommandKind.readCameraStatus:
            final st = await bleClient.readCameraStatus();
            if (st == null) {
              sendResult(success: false);
            } else {
              final (isRec, period) = st;
              sendResult(
                success: true,
                bytes: [
                  isRec ? 1 : 0,
                  period & 0xff,
                  (period >> 8) & 0xff,
                ],
              );
            }
            break;
          case DeviceCommandKind.readRTC:
            final rtcData = await bleClient.readRTC();
            sendResult(success: rtcData != null, bytes: rtcData?.toList());
            break;
          case DeviceCommandKind.writeRTC:
            final rtcBytes = request.bytes;

            if (rtcBytes == null) {
              sendResult(success: false);
              return;
            }

            final success =
                await bleClient.writeRTC(Uint8List.fromList(rtcBytes));
            sendResult(success: success);
            break;
          case DeviceCommandKind.readDeviceName:
            final name = await bleClient.readDeviceName();
            sendResult(success: name != null, text: name);
            break;
          case DeviceCommandKind.writeDeviceName:
            final name = request.name;
            if (name == null) {
              sendResult(success: false);
              return;
            }
            final success = await bleClient.writeDeviceName(name);
            sendResult(success: success);
            break;
          case DeviceCommandKind.writeFileRx:
            final fileRxBytes = request.bytes;
            if (fileRxBytes == null) {
              sendResult(success: false);
              return;
            }
            final success =
                await bleClient.writeFileRx(Uint8List.fromList(fileRxBytes));
            sendResult(success: success);
            break;
          case DeviceCommandKind.readFileCtrl:
            final fileCtrlData = await bleClient.readFileCtrl();
            sendResult(
                success: fileCtrlData != null, bytes: fileCtrlData?.toList());
            break;
          case DeviceCommandKind.writeFileCtrl:
            final fileCtrlBytes = request.bytes;
            if (fileCtrlBytes == null) {
              sendResult(success: false);
              return;
            }
            final success = await bleClient
                .writeFileCtrl(Uint8List.fromList(fileCtrlBytes));
            sendResult(success: success);
            break;
        }
      } catch (e) {
        sendResult(success: false, error: e.toString());
      }
    });

    // File TX stream handler - forward to socket with image header, and to main app for display
    bleClient.onFileTxDataReceived = (data) {
      if (data.length >= 5 && data[0] == 0x00 && data[1] == 0x01) {
        relay.onImagePacket(data);
      } else if (data.length >= 19 && data[0] == 0x00 && data[1] == 0x02) {
        telemetryUploadManager?.handlePacket(data);
      }
      service.invoke('ble.fileTx.data', {'data': data.toList()});
    };

    // ============================================================================
    // 5. BACKGROUND MAINTENANCE
    // ============================================================================

    if (maintenanceTick)
      Timer.periodic(const Duration(seconds: 60), (_) {
        debugPrint("[BLE BG] background tick");
      });

    // ============================================================================
    // 6. STARTUP
    // ============================================================================

    await bleClient.scanAndConnect();
  }
}
