import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:nx_db/auth.dart';
import '../../application/devices/device_command.dart';
import '../../application/devices/device_command_result.dart';
import '../../domain/ble/ble_connection_state.dart';
import '../hardware/camera_command.dart';
import 'background_commands.dart';
import 'background_session_command.dart';

/// Foreground facade. Only this class encodes commands for the service isolate.
class BackgroundServiceClient {
  BackgroundServiceClient({FlutterBackgroundService? service})
      : _service = service ?? FlutterBackgroundService();
  final FlutterBackgroundService _service;
  bool _isInitialized = false;
  int _requestIdCounter = 0;
  StreamSubscription? _commandResultSubscription;
  final Map<int, Completer<DeviceCommandResult?>> _pendingRequests = {};

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
        try {
          completer?.complete(BackgroundCommands.decodeResult(event!));
        } catch (_) {
          completer?.complete(null);
        }
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
    required BackendPreset preset,
    required String clientAppId,
  }) {
    _fileTxLogUserId = userId;
    final command = BackgroundSessionCommand(
        url: url,
        telemetryHttpBaseUrl: telemetryHttpBaseUrl,
        userId: userId,
        preset: preset,
        clientAppId: clientAppId);
    _service.invoke('socket.connect', command.toMap());
  }

  void disconnectSocket() {
    _fileTxLogUserId = '';
    _service.invoke('socket.disconnect');
  }

  void flushGpsBacklog() {
    _service.invoke('gps.flush');
  }

  void updateAppLifecycleState(AppLifecycleState state) {
    _service.invoke('app.lifecycle', {'state': state.name});
  }

  /// Generic command sender with unique request IDs
  Future<T?> _sendCommand<T>({
    required DeviceCommand command,
    required T? Function(DeviceCommandResult?) responseParser,
    T? Function()? timeoutValue,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final requestId = ++_requestIdCounter;
    final completer = Completer<DeviceCommandResult?>();

    // Register pending request BEFORE sending command to avoid race condition
    _pendingRequests[requestId] = completer;

    _service.invoke(
        'ble.command', BackgroundCommands.encode(command, requestId));

    try {
      final event = await completer.future.timeout(timeout, onTimeout: () {
        _pendingRequests.remove(requestId);
        return null;
      });

      if (event == null) {
        return timeoutValue?.call();
      }

      // Verify command matches (safety check)
      final eventCommand = event.kind;
      if (eventCommand != command.kind) {
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
          command:
              DeviceCommand(DeviceCommandKind.writeHaptic, effectId: effectId),
          responseParser: (event) => event?.success ?? false,
          timeoutValue: () => false,
        ) ??
        false;
  }

  /// Write to camera characteristic.
  /// [data] is the raw payload from [CameraCommand.toBytes].
  Future<bool> writeCamera(Uint8List data) async {
    return await _sendCommand<bool>(
          command: DeviceCommand(DeviceCommandKind.writeCamera, bytes: data),
          responseParser: (event) => event?.success ?? false,
          timeoutValue: () => false,
        ) ??
        false;
  }

  /// Read battery data
  Future<Uint8List?> readBattery() async {
    return await _sendCommand<Uint8List>(
      command: DeviceCommand(DeviceCommandKind.readBattery),
      responseParser: (event) {
        final dataList = event?.bytes;
        if (dataList != null) {
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
      command: DeviceCommand(DeviceCommandKind.readCameraStatus),
      responseParser: (event) {
        if (event?.success != true) return null;
        final dataList = event?.bytes;
        if (dataList == null || dataList.length < 3) return null;
        final flags = dataList[0];
        final lo = dataList[1];
        final hi = dataList[2];
        final period = lo | (hi << 8);
        return ((flags & 1) != 0, period.clamp(1, 1000));
      },
      timeoutValue: () => null,
    );
  }

  /// Read RTC time
  Future<Uint8List?> readRTC() async {
    return await _sendCommand<Uint8List>(
      command: DeviceCommand(DeviceCommandKind.readRTC),
      responseParser: (event) {
        final dataList = event?.bytes;
        if (dataList != null) {
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
          command: DeviceCommand(DeviceCommandKind.writeRTC, bytes: data),
          responseParser: (event) => event?.success ?? false,
          timeoutValue: () => false,
        ) ??
        false;
  }

  /// Read device name
  Future<String?> readDeviceName() async {
    return await _sendCommand<String>(
      command: DeviceCommand(DeviceCommandKind.readDeviceName),
      responseParser: (event) => event?.text,
      timeoutValue: () => null,
    );
  }

  /// Write device name
  Future<bool> writeDeviceName(String name) async {
    return await _sendCommand<bool>(
          command: DeviceCommand(DeviceCommandKind.writeDeviceName, name: name),
          responseParser: (event) => event?.success ?? false,
          timeoutValue: () => false,
        ) ??
        false;
  }

  /// Write file RX data
  Future<bool> writeFileRx(Uint8List data) async {
    return await _sendCommand<bool>(
          command: DeviceCommand(DeviceCommandKind.writeFileRx, bytes: data),
          responseParser: (event) => event?.success ?? false,
          timeoutValue: () => false,
        ) ??
        false;
  }

  /// Read file control
  Future<Uint8List?> readFileCtrl() async {
    return await _sendCommand<Uint8List>(
      command: DeviceCommand(DeviceCommandKind.readFileCtrl),
      responseParser: (event) {
        final dataList = event?.bytes;
        if (dataList != null) {
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
          command: DeviceCommand(DeviceCommandKind.writeFileCtrl, bytes: data),
          responseParser: (event) => event?.success ?? false,
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
