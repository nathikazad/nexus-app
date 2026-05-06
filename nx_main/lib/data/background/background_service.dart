import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'package:nx_db/nx_db.dart';
import 'package:nexus_voice_assistant/core/logging/logging_service.dart';
import 'package:nexus_voice_assistant/data/ble/bg_ble_client.dart'
    show BleClient;
import 'package:nexus_voice_assistant/data/hardware/camera_command.dart';
import 'package:nexus_voice_assistant/data/socket/bg_socket_client.dart';
import 'package:nexus_voice_assistant/data/telemetry/telemetry_upload_manager.dart';
import 'package:nexus_voice_assistant/domain/ble/ble_connection_state.dart';

String _httpBaseFromSocketUrl(String socketUrl) {
  final uri = Uri.parse(socketUrl);
  final scheme = uri.scheme == 'wss' ? 'https' : 'http';
  final port = uri.hasPort && uri.port == 8002 ? 8001 : uri.port;
  return Uri(
    scheme: scheme,
    host: uri.host,
    port: port,
  ).toString().replaceAll(RegExp(r'/+$'), '');
}

class BleBackgroundService {
  /// Start the background service (called from onStart entry point)
  static Future<void> startBackgroundService(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    // ============================================================================
    // 1. INITIALIZATION
    // ============================================================================

    final bleClient = BleClient();
    final socketClient = SocketClient();
    TelemetryUploadManager? telemetryUploadManager;

    // ============================================================================
    // 2. BLE CONFIGURATION
    // ============================================================================

    int packetCount = 0;
    int textPacketCount = 0;
    int imagePacketCount = 0;
    int audioPacketCount = 0;
    bool audioSendActive = false;
    int audioSendPacketCount = 0;
    int audioSendByteCount = 0;

    String utcNow() => DateTime.now().toUtc().toIso8601String();

    bleClient.onConnectionStateChanged = (state) {
      debugPrint("[BLE BG] Connection state: ${state.name}");
      service.invoke('ble.status', {'status': state.name});
    };

    bleClient.onAudioPacketReceived = (data) {
      packetCount++;
      // Byte 2 is 1-byte packet_index from ESP32 (format: [0x01][0x00][packet_index][size:2][opus])
      final packetIndex = data.length >= 3 ? data[2] : 0;
      service.invoke('ble.packet', {
        'count': packetCount,
        'packet_index': packetIndex,
        'size': data.length,
      });

      final isAudioEof = data.length == 2 && data[0] == 0xFC && data[1] == 0xFF;
      if (!audioSendActive) {
        audioSendActive = true;
        audioSendPacketCount = 0;
        audioSendByteCount = 0;
        debugPrint("[BLE BG] ${utcNow()} UTC audio packets sending started");
      }
      audioSendPacketCount++;
      // Count WebSocket wire bytes: 6-byte OPUS_AUDIO_PACKET wrapper + BLE payload.
      audioSendByteCount += 6 + data.length;

      // Forward BLE payload with 4B index (consistent with text/image/EOF)
      audioPacketCount++;
      socketClient.sendPacket(data, index: audioPacketCount);
      if (isAudioEof) {
        debugPrint(
          "[BLE BG] ${utcNow()} UTC audio packets sending finished "
          "$audioSendPacketCount packets, $audioSendByteCount bytes",
        );
        audioSendActive = false;
      }
      // Send ACK back to the device
      bleClient
          .sendAudio(Uint8List.fromList([0x41, 0x43, 0x4B])); // "ACK" in ASCII
    };

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

    bleClient.onDiagnosticLog = (message) {
      service.invoke('ble.debugLog', {'message': message});
    };

    await bleClient.initialize();

    // ============================================================================
    // 3. SOCKET CONFIGURATION
    // ============================================================================

    // Forward packets from server to BLE
    socketClient.onPacketFromServer = (packet) => bleClient.sendAudio(packet);

    // Handle device requests (e.g. take_photo, camera record)
    socketClient.onDeviceRequest = (requestId, action, params) async {
      try {
        switch (action) {
          case 'take_photo':
            final success =
                await bleClient.writeCamera(CameraCommand.capture.toBytes());
            return jsonEncode({'success': success});
          case 'get_camera_status':
            final st = await bleClient.readCameraStatus();
            if (st == null) return jsonEncode({'success': false});
            final (isRecording, periodSec) = st;
            return jsonEncode({
              'success': true,
              'isRecording': isRecording,
              'periodSec': periodSec,
            });
          case 'start_record':
            final periodSec = (params['periodSec'] as num?)?.toInt() ?? 60;
            final periodOk = await bleClient.writeCamera(
              CameraCommand.setRecordPeriod
                  .toBytes(period: periodSec.clamp(1, 1000)),
            );
            if (!periodOk) return jsonEncode({'success': false});
            final startOk = await bleClient
                .writeCamera(CameraCommand.startRecord.toBytes());
            return jsonEncode({'success': startOk});
          case 'stop_record':
            final success =
                await bleClient.writeCamera(CameraCommand.stopRecord.toBytes());
            return jsonEncode({'success': success});
          case 'set_record_period':
            final periodSec = (params['periodSec'] as num?)?.toInt();
            if (periodSec == null || periodSec < 1 || periodSec > 1000) {
              return jsonEncode(
                  {'success': false, 'error': 'periodSec required (1-1000)'});
            }
            final success = await bleClient.writeCamera(
              CameraCommand.setRecordPeriod.toBytes(period: periodSec),
            );
            return jsonEncode({'success': success});
          case 'get_battery':
            final raw = await bleClient.readBattery();
            final parsed =
                raw != null ? BleClient.parseBatteryStatus(raw) : null;
            if (parsed == null) {
              return jsonEncode(
                  {'success': false, 'error': 'battery unavailable'});
            }
            final (:voltageMv, :percent, :charging, :timeIso, :timezone) =
                parsed;
            final out = <String, dynamic>{
              'success': true,
              'voltageMv': voltageMv,
              'percent': percent,
              'charging': charging,
            };
            if (timeIso != null) out['time'] = timeIso;
            if (timezone != null) out['timezone'] = timezone;
            return jsonEncode(out);
          case 'vibrate':
            final effectId =
                ((params['effectId'] as num?)?.toInt() ?? 16).clamp(0, 123);
            final success = await bleClient.writeHaptic(effectId);
            return jsonEncode({'success': success});
          case 'power_cycle':
            final success =
                await bleClient.writeCamera(CameraCommand.powerCycle.toBytes());
            return jsonEncode({'success': success});
          default:
            return null;
        }
      } catch (e) {
        debugPrint("[BLE BG] Device request $action error: $e");
        return jsonEncode({'success': false, 'error': e.toString()});
      }
    };

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
    service.on('socket.connect').listen((event) async {
      final url = event?['url'] as String?;
      final userId = event?['userId'] as String?;
      final personalDomainId = event?['personalDomainId'] as int?;
      final sharedDomainId = event?['sharedDomainId'] as int?;
      final telemetryHttpBaseUrl = event?['telemetryHttpBaseUrl'] as String?;

      if (url == null ||
          url.isEmpty ||
          userId == null ||
          userId.isEmpty ||
          personalDomainId == null ||
          sharedDomainId == null) {
        debugPrint(
          '[Socket] Ignoring connect without complete auth session '
          '(url=${url != null && url.isNotEmpty}, '
          'userId=${userId != null && userId.isNotEmpty}, '
          'personalDomainId=${personalDomainId != null}, '
          'sharedDomainId=${sharedDomainId != null})',
        );
        await socketClient.disconnect();
        return;
      }

      final headers = <String, String>{
        'X-User-Id': userId,
        'X-Personal-Domain-Id': personalDomainId.toString(),
        'X-Shared-Domain-Id': sharedDomainId.toString(),
        if (CfAccess.shouldAttachHeaders(url)) ...CfAccess.headers,
      };
      final uploadBase = telemetryHttpBaseUrl?.isNotEmpty == true
          ? telemetryHttpBaseUrl!
          : _httpBaseFromSocketUrl(url);
      telemetryUploadManager = TelemetryUploadManager(
        httpBaseUrl: uploadBase,
        headers: {
          'X-User-Id': userId,
          if (CfAccess.shouldAttachHeaders(uploadBase)) ...CfAccess.headers,
        },
        onCommitted: (transferId) async {
          await bleClient.writeFileRx(telemetryCommittedAck(transferId));
          service.invoke('ble.debugLog', {
            'message': 'Telemetry upload committed transfer=$transferId',
          });
        },
      );
      await socketClient.disconnect();
      await socketClient.connect(url, headers: headers);
    });

    service.on('socket.disconnect').listen((event) async {
      await socketClient.disconnect();
    });

    // Socket text events
    service.on('socket.sendText').listen((event) {
      final text = event?['text'] as String?;
      if (text != null && text.isNotEmpty) {
        textPacketCount++;
        socketClient.sendTextPacket(text, textPacketCount);
        debugPrint(
            "[BLE BG] Sent text packet #$textPacketCount: ${text.length} chars");
      }
    });

    service.on('socket.sendEof').listen((event) {
      textPacketCount++;
      socketClient.sendTextEofPacket(textPacketCount);
      debugPrint("[BLE BG] Sent TEXT_EOF packet #$textPacketCount");
      // Reset counter after EOF for next turn
      textPacketCount = 0;
    });

    // Service lifecycle events
    service.on('stop').listen((event) async {
      await bleClient.disconnect(intentional: true);
      await socketClient.disconnect();
      service.stopSelf();
    });

    // Unified BLE command handler
    service.on('ble.command').listen((event) async {
      final command = event?['command'] as String?;
      final requestId = event?['requestId'] as int?;
      final data = event?['data'];

      // Helper to send response with request ID
      void sendResult(Map<String, dynamic> result) {
        result['command'] = command;
        if (requestId != null) {
          result['requestId'] = requestId;
        }
        service.invoke('ble.command.result', result);
      }

      try {
        switch (command) {
          case 'writeHaptic':
            final effectId = data?['effectId'] as int? ?? 16;
            final success = await bleClient.writeHaptic(effectId);
            sendResult({'success': success});
            break;
          case 'writeCamera':
            final rawData = data?['data'];
            if (rawData is! List || rawData.isEmpty) {
              sendResult({'success': false});
              return;
            }
            final success = await bleClient
                .writeCamera(Uint8List.fromList(List<int>.from(rawData)));
            sendResult({'success': success});
            break;
          case 'readBattery':
            final batteryData = await bleClient.readBattery();
            sendResult({
              'success': batteryData != null,
              'data': batteryData?.toList(),
            });
            break;
          case 'readCameraStatus':
            final st = await bleClient.readCameraStatus();
            if (st == null) {
              sendResult({'success': false});
            } else {
              final (isRec, period) = st;
              sendResult({
                'success': true,
                'data': [
                  isRec ? 1 : 0,
                  period & 0xff,
                  (period >> 8) & 0xff,
                ],
              });
            }
            break;
          case 'readRTC':
            final rtcData = await bleClient.readRTC();
            sendResult({
              'success': rtcData != null,
              'data': rtcData?.toList(),
            });
            break;
          case 'writeRTC':
            final rtcBytes = data?['data'];

            if (rtcBytes == null) {
              sendResult({'success': false});
              return;
            }

            // Handle List<dynamic> -> List<int> conversion
            List<int>? intList;
            if (rtcBytes is List) {
              try {
                intList = List<int>.from(rtcBytes);
              } catch (e) {
                sendResult({'success': false, 'error': 'Invalid data format'});
                return;
              }
            } else {
              sendResult({'success': false, 'error': 'Data is not a list'});
              return;
            }

            final success =
                await bleClient.writeRTC(Uint8List.fromList(intList));
            sendResult({'success': success});
            break;
          case 'readDeviceName':
            final name = await bleClient.readDeviceName();
            sendResult({
              'success': name != null,
              'data': name,
            });
            break;
          case 'writeDeviceName':
            final name = data?['name'] as String?;
            if (name == null) {
              sendResult({'success': false});
              return;
            }
            final success = await bleClient.writeDeviceName(name);
            sendResult({'success': success});
            break;
          case 'writeFileRx':
            final fileRxBytes = data?['data'] as List<int>?;
            if (fileRxBytes == null) {
              sendResult({'success': false});
              return;
            }
            final success =
                await bleClient.writeFileRx(Uint8List.fromList(fileRxBytes));
            sendResult({'success': success});
            break;
          case 'readFileCtrl':
            final fileCtrlData = await bleClient.readFileCtrl();
            sendResult({
              'success': fileCtrlData != null,
              'data': fileCtrlData?.toList(),
            });
            break;
          case 'writeFileCtrl':
            final fileCtrlBytes = data?['data'] as List<int>?;
            if (fileCtrlBytes == null) {
              sendResult({'success': false});
              return;
            }
            final success = await bleClient
                .writeFileCtrl(Uint8List.fromList(fileCtrlBytes));
            sendResult({'success': success});
            break;
          default:
            sendResult({'success': false, 'error': 'Unknown command'});
        }
      } catch (e) {
        sendResult({'success': false, 'error': e.toString()});
      }
    });

    // File TX stream handler - forward to socket with image header, and to main app for display
    bleClient.onFileTxDataReceived = (data) {
      if (data.length >= 5 && data[0] == 0x00 && data[1] == 0x01) {
        imagePacketCount++;
        socketClient.sendImagePacket(data, imagePacketCount);
      } else if (data.length >= 19 && data[0] == 0x00 && data[1] == 0x02) {
        telemetryUploadManager?.handlePacket(data);
      }
      service.invoke('ble.fileTx.data', {'data': data.toList()});
    };

    // ============================================================================
    // 5. BACKGROUND MAINTENANCE
    // ============================================================================

    Timer.periodic(const Duration(seconds: 60), (_) {
      debugPrint("[BLE BG] background tick");
    });

    // ============================================================================
    // 6. STARTUP
    // ============================================================================

    await bleClient.scanAndConnect();
  }

  late FlutterBackgroundService _service;
  bool _isInitialized = false;
  int _requestIdCounter = 0;
  StreamSubscription? _commandResultSubscription;
  final Map<int, Completer<Map<String, dynamic>?>> _pendingRequests = {};

  final StreamController<BleConnectionState> _statusController =
      StreamController<BleConnectionState>.broadcast();
  final StreamController<Uint8List> _fileTxDataController =
      StreamController<Uint8List>.broadcast();
  final StreamController<Map<String, dynamic>> _devicePushController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Last BLE state from the background isolate. Updated on every [statusStream] event.
  /// Use this for [isConnected] checks: broadcast streams do not replay, so subscribers
  /// that attach after `connected` was already emitted would otherwise see [idle] forever.
  BleConnectionState lastKnownBleStatus = BleConnectionState.idle;

  /// For concise File TX logs; refreshed from the active socket session.
  String _fileTxLogUserId = '';

  Stream<BleConnectionState> get statusStream => _statusController.stream;
  Stream<Uint8List> get fileTxStream => _fileTxDataController.stream;
  Stream<Map<String, dynamic>> get devicePushStream =>
      _devicePushController.stream;

  Future<void> init({
    required Future<void> Function(ServiceInstance) onStart,
    required Future<bool> Function(ServiceInstance) onIosBackground,
  }) async {
    if (_isInitialized) return;
    _service = FlutterBackgroundService();

    await _service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        autoStart: true,
        onStart: onStart,
        isForegroundMode: true,
        autoStartOnBoot: true,
      ),
    );

    _isInitialized = true;
  }

  Future<void> start() async {
    await _service.startService();

    _service.on('ble.status').listen((event) {
      final statusStr = event?['status'] as String? ?? 'scanning';
      try {
        final status = BleConnectionState.values.firstWhere(
          (state) => state.name == statusStr,
          orElse: () => BleConnectionState.idle,
        );
        lastKnownBleStatus = status;
        _statusController.add(status);
      } catch (e) {
        // Fallback to scanning if parsing fails
        lastKnownBleStatus = BleConnectionState.idle;
        _statusController.add(BleConnectionState.idle);
      }
    });

    _service.on('ble.debugLog').listen((event) {
      final message = event?['message'] as String?;
      if (message != null && message.isNotEmpty) {
        LoggingService.instance.log('[BLE] $message');
      }
    });

    // Re-emit current state from the isolate so late subscribers are not stuck on [idle]
    // after missing earlier `ble.status` events (broadcast stream has no replay).
    _service.invoke('ble.syncStatus');

    _service.on('ble.error').listen((event) {
      final error = event?['error'] ?? 'Unknown error';
      debugPrint("[BLE BG] Error: $error");
      // Don't add error to status stream, keep current state
    });

    _service.on('ble.fileTx.data').listen((event) {
      final raw = event?['data'];
      if (raw == null) return;
      final data = raw is List ? List<int>.from(raw) : null;
      if (data == null || data.length < 5) return;
      // Packet: [0]=header, [1]=type, [2]=pkt_num, [3]=total_packets, [4+]=filename\0 + payload
      if (data[0] != 0x00 || data[1] != 0x01) return;
      final pktNum = data[2];
      final totalPkts = data[3];
      int end = 4;
      while (end < data.length && data[end] != 0) end++;
      final filename = String.fromCharCodes(data.sublist(4, end));
      if (pktNum == 0) {
        debugPrint(
            '[File TX] sending image $filename $totalPkts as $_fileTxLogUserId');
      }
      if (pktNum + 1 == totalPkts) {
        debugPrint('[File TX] finished sent $totalPkts packets');
      }
    });

    _service.on('device.push').listen((event) {
      if (event is Map<String, dynamic>) {
        _devicePushController.add(event);
      }
    });

    // Set up single shared subscription for command results
    _commandResultSubscription?.cancel();
    _commandResultSubscription =
        _service.on('ble.command.result').listen((event) {
      final requestId = event?['requestId'] as int?;
      if (requestId != null && _pendingRequests.containsKey(requestId)) {
        final completer = _pendingRequests.remove(requestId);
        completer?.complete(event);
      }
    });
  }

  void startBle() {
    _service.invoke('ble.start');
  }

  /// Pushes the saved [remoteId] to the background isolate and reconnects.
  void applyPairedRemoteId(String remoteId) {
    _service.invoke('ble.applyPairedRemoteId', {'remoteId': remoteId});
  }

  /// Clears pairing storage on the isolate and disconnects (no auto-reconnect).
  void clearPairedRemoteId() {
    _service.invoke('ble.clearPairedRemoteId');
  }

  void stopBle() {
    _service.invoke('ble.stop');
  }

  void stopService() {
    _service.invoke('stop');
  }

  void connectSocket({
    required String url,
    required String telemetryHttpBaseUrl,
    required String userId,
    required int personalDomainId,
    required int sharedDomainId,
  }) {
    _fileTxLogUserId = userId;
    _service.invoke('socket.connect', {
      'url': url,
      'telemetryHttpBaseUrl': telemetryHttpBaseUrl,
      'userId': userId,
      'personalDomainId': personalDomainId,
      'sharedDomainId': sharedDomainId,
    });
  }

  void disconnectSocket() {
    _fileTxLogUserId = '';
    _service.invoke('socket.disconnect');
  }

  /// Send text to the socket server
  void sendTextToSocket(String text) {
    _service.invoke('socket.sendText', {'text': text});
  }

  /// Send EOF packet to the socket server
  void sendEofToSocket() {
    _service.invoke('socket.sendEof');
  }

  /// Generic command sender with unique request IDs
  Future<T?> _sendCommand<T>({
    required String command,
    Map<String, dynamic>? data,
    required T? Function(Map<String, dynamic>?) responseParser,
    T? Function()? timeoutValue,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final requestId = ++_requestIdCounter;
    final completer = Completer<Map<String, dynamic>?>();

    // Register pending request BEFORE sending command to avoid race condition
    _pendingRequests[requestId] = completer;

    final commandData = <String, dynamic>{
      'command': command,
      'requestId': requestId,
    };
    if (data != null) {
      commandData['data'] = data;
    }

    // Send command after subscription is ready
    _service.invoke('ble.command', commandData);

    try {
      final event = await completer.future.timeout(timeout, onTimeout: () {
        _pendingRequests.remove(requestId);
        return null;
      });

      if (event == null) {
        return timeoutValue?.call();
      }

      // Verify command matches (safety check)
      final eventCommand = event['command'] as String?;
      if (eventCommand != command) {
        return timeoutValue?.call();
      }

      return responseParser(event);
    } catch (e) {
      _pendingRequests.remove(requestId);
      return timeoutValue?.call();
    }
  }

  /// Write haptic effect
  Future<bool> writeHaptic(int effectId) async {
    return await _sendCommand<bool>(
          command: 'writeHaptic',
          data: {'effectId': effectId},
          responseParser: (event) => event?['success'] as bool? ?? false,
          timeoutValue: () => false,
        ) ??
        false;
  }

  /// Write to camera characteristic.
  /// [data] is the raw payload from [CameraCommand.toBytes].
  Future<bool> writeCamera(Uint8List data) async {
    return await _sendCommand<bool>(
          command: 'writeCamera',
          data: {'data': data.toList()},
          responseParser: (event) => event?['success'] as bool? ?? false,
          timeoutValue: () => false,
        ) ??
        false;
  }

  /// Read battery data
  Future<Uint8List?> readBattery() async {
    return await _sendCommand<Uint8List>(
      command: 'readBattery',
      responseParser: (event) {
        final dataList = event?['data'];
        if (dataList is List) {
          return Uint8List.fromList(List<int>.from(dataList));
        }
        return null;
      },
      timeoutValue: () => null,
    );
  }

  /// Read camera record status (is recording, period seconds). Null on failure.
  Future<(bool isRecording, int periodSec)?> readCameraStatus() async {
    return await _sendCommand<(bool isRecording, int periodSec)>(
      command: 'readCameraStatus',
      responseParser: (event) {
        if (event?['success'] != true) return null;
        final dataList = event?['data'];
        if (dataList is! List || dataList.length < 3) return null;
        final flags = dataList[0] as int;
        final lo = dataList[1] as int;
        final hi = dataList[2] as int;
        final period = lo | (hi << 8);
        return ((flags & 1) != 0, period.clamp(1, 1000));
      },
      timeoutValue: () => null,
    );
  }

  /// Read RTC time
  Future<Uint8List?> readRTC() async {
    return await _sendCommand<Uint8List>(
      command: 'readRTC',
      responseParser: (event) {
        final dataList = event?['data'];
        if (dataList is List) {
          return Uint8List.fromList(List<int>.from(dataList));
        }
        return null;
      },
      timeoutValue: () => null,
    );
  }

  /// Write RTC time
  Future<bool> writeRTC(Uint8List data) async {
    return await _sendCommand<bool>(
          command: 'writeRTC',
          data: {'data': data.toList()},
          responseParser: (event) => event?['success'] as bool? ?? false,
          timeoutValue: () => false,
        ) ??
        false;
  }

  /// Read device name
  Future<String?> readDeviceName() async {
    return await _sendCommand<String>(
      command: 'readDeviceName',
      responseParser: (event) => event?['data'] as String?,
      timeoutValue: () => null,
    );
  }

  /// Write device name
  Future<bool> writeDeviceName(String name) async {
    return await _sendCommand<bool>(
          command: 'writeDeviceName',
          data: {'name': name},
          responseParser: (event) => event?['success'] as bool? ?? false,
          timeoutValue: () => false,
        ) ??
        false;
  }

  /// Write file RX data
  Future<bool> writeFileRx(Uint8List data) async {
    return await _sendCommand<bool>(
          command: 'writeFileRx',
          data: {'data': data.toList()},
          responseParser: (event) => event?['success'] as bool? ?? false,
          timeoutValue: () => false,
        ) ??
        false;
  }

  /// Read file control
  Future<Uint8List?> readFileCtrl() async {
    return await _sendCommand<Uint8List>(
      command: 'readFileCtrl',
      responseParser: (event) {
        final dataList = event?['data'];
        if (dataList is List) {
          return Uint8List.fromList(List<int>.from(dataList));
        }
        return null;
      },
      timeoutValue: () => null,
    );
  }

  /// Write file control
  Future<bool> writeFileCtrl(Uint8List data) async {
    return await _sendCommand<bool>(
          command: 'writeFileCtrl',
          data: {'data': data.toList()},
          responseParser: (event) => event?['success'] as bool? ?? false,
          timeoutValue: () => false,
        ) ??
        false;
  }

  void dispose() {
    _commandResultSubscription?.cancel();
    _pendingRequests.clear();
    _statusController.close();
    _fileTxDataController.close();
    _devicePushController.close();
  }
}
