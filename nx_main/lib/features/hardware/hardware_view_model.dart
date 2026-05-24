import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_voice_assistant/data/hardware/camera_command.dart';
import 'package:nexus_voice_assistant/data/hardware/hardware_service.dart';
import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nexus_voice_assistant/domain/ble/ble_connection_state.dart';

const Object _hwCopyUnset = Object();

class HardwareViewState {
  const HardwareViewState({
    this.batteryPercentage,
    this.voltage,
    this.isCharging,
    this.rtcTimeDisplay,
    this.rtcTimezone,
    this.deviceName,
    required this.isConnected,
    required this.isSettingRTC,
    required this.isPulsingHaptic,
    required this.isPowerCycling,
    required this.isTriggeringCamera,
    required this.isSettingDeviceName,
    this.pairedRemoteId,
    required this.menuOpen,
    this.snackbarMessage,
  });

  final int? batteryPercentage;
  final double? voltage;
  final bool? isCharging;
  final String? rtcTimeDisplay;
  final String? rtcTimezone;
  final String? deviceName;
  final bool isConnected;
  final bool isSettingRTC;
  final bool isPulsingHaptic;
  final bool isPowerCycling;
  final bool isTriggeringCamera;
  final bool isSettingDeviceName;
  final String? pairedRemoteId;
  final bool menuOpen;
  final String? snackbarMessage;

  factory HardwareViewState.initial(HardwareService hw) {
    return HardwareViewState(
      isConnected: hw.isConnected,
      isSettingRTC: false,
      isPulsingHaptic: false,
      isPowerCycling: false,
      isTriggeringCamera: false,
      isSettingDeviceName: false,
      menuOpen: false,
    );
  }

  HardwareViewState copyWith({
    Object? batteryPercentage = _hwCopyUnset,
    Object? voltage = _hwCopyUnset,
    Object? isCharging = _hwCopyUnset,
    Object? rtcTimeDisplay = _hwCopyUnset,
    Object? rtcTimezone = _hwCopyUnset,
    Object? deviceName = _hwCopyUnset,
    bool? isConnected,
    bool? isSettingRTC,
    bool? isPulsingHaptic,
    bool? isPowerCycling,
    bool? isTriggeringCamera,
    bool? isSettingDeviceName,
    Object? pairedRemoteId = _hwCopyUnset,
    bool? menuOpen,
    Object? snackbarMessage = _hwCopyUnset,
    bool clearSnackbar = false,
    bool clearDeviceReadouts = false,
  }) {
    return HardwareViewState(
      batteryPercentage: clearDeviceReadouts
          ? null
          : (identical(batteryPercentage, _hwCopyUnset)
              ? this.batteryPercentage
              : batteryPercentage as int?),
      voltage: clearDeviceReadouts
          ? null
          : (identical(voltage, _hwCopyUnset)
              ? this.voltage
              : voltage as double?),
      isCharging: clearDeviceReadouts
          ? null
          : (identical(isCharging, _hwCopyUnset)
              ? this.isCharging
              : isCharging as bool?),
      rtcTimeDisplay: clearDeviceReadouts
          ? null
          : (identical(rtcTimeDisplay, _hwCopyUnset)
              ? this.rtcTimeDisplay
              : rtcTimeDisplay as String?),
      rtcTimezone: clearDeviceReadouts
          ? null
          : (identical(rtcTimezone, _hwCopyUnset)
              ? this.rtcTimezone
              : rtcTimezone as String?),
      deviceName: clearDeviceReadouts
          ? null
          : (identical(deviceName, _hwCopyUnset)
              ? this.deviceName
              : deviceName as String?),
      isConnected: isConnected ?? this.isConnected,
      isSettingRTC: isSettingRTC ?? this.isSettingRTC,
      isPulsingHaptic: isPulsingHaptic ?? this.isPulsingHaptic,
      isPowerCycling: isPowerCycling ?? this.isPowerCycling,
      isTriggeringCamera: isTriggeringCamera ?? this.isTriggeringCamera,
      isSettingDeviceName: isSettingDeviceName ?? this.isSettingDeviceName,
      pairedRemoteId: identical(pairedRemoteId, _hwCopyUnset)
          ? this.pairedRemoteId
          : pairedRemoteId as String?,
      menuOpen: menuOpen ?? this.menuOpen,
      snackbarMessage: clearSnackbar
          ? null
          : (identical(snackbarMessage, _hwCopyUnset)
              ? this.snackbarMessage
              : snackbarMessage as String?),
    );
  }
}

class HardwareViewNotifier extends Notifier<HardwareViewState> {
  StreamSubscription<BleConnectionState>? _connectionSubscription;
  StreamSubscription<Map<String, dynamic>>? _devicePushSubscription;
  Timer? _dataRefreshTimer;
  bool _listenersAttached = false;

  HardwareService get _hw => ref.read(hardwareServiceProvider);

  @override
  HardwareViewState build() {
    ref.onDispose(() {
      _stopRefreshTimers();
      _connectionSubscription?.cancel();
      _devicePushSubscription?.cancel();
    });

    if (!_listenersAttached) {
      _listenersAttached = true;
      Future.microtask(_attachListeners);
    }

    return stateOrNull ?? HardwareViewState.initial(_hw);
  }

  void clearSnackbar() {
    if (state.snackbarMessage != null) {
      state = state.copyWith(clearSnackbar: true);
    }
  }

  void toggleMenu() {
    state = state.copyWith(menuOpen: !state.menuOpen);
  }

  void closeMenu() {
    if (state.menuOpen) {
      state = state.copyWith(menuOpen: false);
    }
  }

  String rememberedDisplayName() {
    final n = (state.deviceName ?? _hw.deviceName)?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Your Nexus';
  }

  Future<void> loadPairedRemoteId() async {
    final id = await _hw.getPairedRemoteId();
    state = state.copyWith(pairedRemoteId: id);
  }

  Future<void> onReturnFromDeviceSelection() async {
    await loadPairedRemoteId();
    state = state.copyWith(isConnected: _hw.isConnected);
  }

  void _stopRefreshTimers() {
    _dataRefreshTimer?.cancel();
    _dataRefreshTimer = null;
  }

  Future<void> _startRefreshTimers() async {
    await readBatteryData();
    await readRTCData();
    await readDeviceName();

    _dataRefreshTimer?.cancel();
    _dataRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await readRTCData();
    });
  }

  Future<void> readBatteryData() async {
    if (!state.isConnected) return;
    try {
      final batteryData = await _hw.readBattery();
      if (batteryData != null) {
        state = state.copyWith(
          batteryPercentage: batteryData.percentage,
          voltage: batteryData.voltage,
          isCharging: batteryData.isCharging,
        );
      }
    } catch (e) {
      debugPrint('Error reading battery data: $e');
    }
  }

  Future<void> readRTCData() async {
    if (!state.isConnected) return;
    try {
      final rtcTime = await _hw.readRTC();
      if (rtcTime != null) {
        final tzHours = rtcTime.timezoneHours;
        final tzStr = tzHours >= 0 ? '+$tzHours' : '$tzHours';
        state = state.copyWith(
          rtcTimeDisplay: rtcTime.toDisplayString(),
          rtcTimezone: tzStr,
        );
      }
    } catch (e) {
      debugPrint('Error reading RTC data: $e');
    }
  }

  Future<void> readDeviceName() async {
    debugPrint('Reading device name');
    if (!state.isConnected) return;
    try {
      debugPrint('Reading device name from device');
      final name = await _hw.readDeviceName();
      debugPrint('Device name read: $name');
      state = state.copyWith(
        deviceName: name ?? _hw.deviceName,
      );
    } catch (e) {
      debugPrint('Error reading device name: $e');
      state = state.copyWith(deviceName: _hw.deviceName);
    }
  }

  Future<void> submitDeviceName(String name) async {
    if (!state.isConnected || state.isSettingDeviceName) return;
    state = state.copyWith(isSettingDeviceName: true);
    try {
      final success = await _hw.writeDeviceName(name);
      if (success) {
        state = state.copyWith(
          snackbarMessage: 'Device name updated successfully',
        );
        await readDeviceName();
      } else {
        state = state.copyWith(
          snackbarMessage: 'Failed to update device name',
        );
      }
    } catch (e) {
      state = state.copyWith(
        snackbarMessage: 'Error updating device name: $e',
      );
    } finally {
      state = state.copyWith(isSettingDeviceName: false);
    }
  }

  Future<void> setRtcTimeNow() async {
    if (!state.isConnected || state.isSettingRTC) return;
    state = state.copyWith(isSettingRTC: true);
    try {
      final success = await _hw.setRTCTimeNow();
      if (success) {
        state = state.copyWith(snackbarMessage: 'RTC time set successfully');
        await readRTCData();
      } else {
        state = state.copyWith(snackbarMessage: 'Failed to set RTC time');
      }
    } catch (e) {
      state = state.copyWith(snackbarMessage: 'Error setting RTC time: $e');
    } finally {
      state = state.copyWith(isSettingRTC: false);
    }
  }

  Future<void> pulseHaptic() async {
    if (!state.isConnected || state.isPulsingHaptic) return;
    state = state.copyWith(isPulsingHaptic: true);
    try {
      final success = await _hw.triggerHapticPulse();
      if (!success) {
        state = state.copyWith(
          snackbarMessage: 'Failed to trigger haptic pulse',
        );
      }
    } catch (e) {
      state = state.copyWith(
        snackbarMessage: 'Error triggering haptic pulse: $e',
      );
    } finally {
      state = state.copyWith(isPulsingHaptic: false);
    }
  }

  Future<void> powerCycle() async {
    if (!state.isConnected || state.isPowerCycling) return;
    state = state.copyWith(isPowerCycling: true);
    try {
      final success = await _hw.sendCameraCommand(CameraCommand.powerCycle);
      if (success) {
        state = state.copyWith(
          snackbarMessage: 'Power cycle sent — device will restart',
        );
      } else {
        state = state.copyWith(snackbarMessage: 'Failed to send power cycle');
      }
    } catch (e) {
      state = state.copyWith(snackbarMessage: 'Error sending power cycle: $e');
    } finally {
      state = state.copyWith(isPowerCycling: false);
    }
  }

  Future<void> triggerCamera() async {
    if (!state.isConnected || state.isTriggeringCamera) return;
    state = state.copyWith(isTriggeringCamera: true);
    try {
      final success = await _hw.sendCameraCommand(CameraCommand.capture);
      if (!success) {
        state = state.copyWith(snackbarMessage: 'Failed to trigger camera');
      }
    } catch (e) {
      state = state.copyWith(snackbarMessage: 'Error triggering camera: $e');
    } finally {
      state = state.copyWith(isTriggeringCamera: false);
    }
  }

  Future<void> forgetPairedAfterConfirm() async {
    await _hw.forgetPairedDevice();
    await loadPairedRemoteId();
    state = state.copyWith(
      isConnected: _hw.isConnected,
      snackbarMessage: 'Saved device cleared',
      clearDeviceReadouts: true,
    );
  }

  void reconnectPaired() {
    final id = state.pairedRemoteId;
    if (id == null || id.isEmpty) return;
    ref.read(bleBackgroundServiceProvider).applyPairedRemoteId(id);
    state = state.copyWith(snackbarMessage: 'Connecting…');
  }

  void disconnectBle() {
    ref.read(bleBackgroundServiceProvider).stopBle();
    state = state.copyWith(snackbarMessage: 'Disconnected from device');
  }

  void _attachListeners() {
    _connectionSubscription = _hw.statusStream.listen((status) {
      final isConnected = status == BleConnectionState.connected;
      if (isConnected) {
        state = state.copyWith(isConnected: true);
        unawaited(_startRefreshTimers());
      } else {
        _stopRefreshTimers();
        state = state.copyWith(
          isConnected: false,
          clearDeviceReadouts: true,
        );
      }
    });

    _devicePushSubscription =
        ref.read(bleBackgroundServiceProvider).devicePushStream.listen((event) {
      if (event['type'] != 'battery') return;
      final percent = event['percent'] as int?;
      final voltageMv = event['voltageMv'] as int?;
      final charging = event['charging'] as bool?;
      if (percent == null || voltageMv == null || charging == null) return;
      state = state.copyWith(
        batteryPercentage: percent,
        voltage: voltageMv / 1000.0,
        isCharging: charging,
      );
    });

    state = state.copyWith(isConnected: _hw.isConnected);
    unawaited(loadPairedRemoteId());
    if (_hw.isConnected) {
      unawaited(_startRefreshTimers());
    }
  }
}

final hardwareViewModelProvider =
    NotifierProvider<HardwareViewNotifier, HardwareViewState>(
  HardwareViewNotifier.new,
);
