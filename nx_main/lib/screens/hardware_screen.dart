import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nexus_voice_assistant/app_theme.dart';
import 'package:nexus_voice_assistant/layout.dart';
import 'package:nexus_voice_assistant/background_service.dart' show bleBackgroundServiceProvider;
import 'package:nexus_voice_assistant/services/hardware_service/hardware_service.dart';
import 'package:nexus_voice_assistant/services/hardware_service/camera_command.dart';
import 'package:nexus_voice_assistant/services/logging_service.dart';
import 'package:nexus_voice_assistant/bg_ble_client.dart';
import 'package:nexus_voice_assistant/widgets/camera_section.dart';
import 'device_selection_screen.dart';

class HardwareScreen extends ConsumerStatefulWidget {
  const HardwareScreen({super.key});

  @override
  ConsumerState<HardwareScreen> createState() => _HardwareScreenState();
}

class _HardwareScreenState extends ConsumerState<HardwareScreen> {
  late final HardwareService _hardwareService;
  
  int? _batteryPercentage;
  double? _voltage;
  bool? _isCharging;
  String? _rtcTimeDisplay;
  String? _rtcTimezone; // Will store formatted timezone (e.g., "-8")
  String? _deviceName;
  bool _isConnected = false;
  bool _isSettingRTC = false;
  bool _isPulsingHaptic = false;
  bool _isPowerCycling = false;
  bool _isTriggeringCamera = false;
  bool _isSettingDeviceName = false;
  String? _pairedRemoteId;

  StreamSubscription<BleConnectionState>? _connectionSubscription;
  StreamSubscription<Map<String, dynamic>>? _devicePushSubscription;
  Timer? _dataRefreshTimer;

  @override
  void initState() {
    super.initState();
    _hardwareService = ref.read(hardwareServiceProvider);
    _setupListeners();
    _startRefreshTimers();
    _loadPairedRemoteId();
  }

  Future<void> _loadPairedRemoteId() async {
    final id = await _hardwareService.getPairedRemoteId();
    if (mounted) {
      setState(() => _pairedRemoteId = id);
    }
  }

  Future<void> _startRefreshTimers() async {
    // Read immediately
    await _readBatteryData();
    await _readRTCData();
    await _readDeviceName();

    // Refresh RTC periodically; battery updates via BLE notify -> device.push (photo record polls inside [PhotoRecordSection])
    _dataRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _readRTCData();
    });
  }

  Future<void> _readBatteryData() async {
    if (!_isConnected) {
      return;
    }
    try {
      final batteryData = await _hardwareService.readBattery();
      if (mounted && batteryData != null) {
        setState(() {
          _batteryPercentage = batteryData.percentage;
          _voltage = batteryData.voltage;
          _isCharging = batteryData.isCharging;
        });
      }
    } catch (e) {
      LoggingService.instance.log('Error reading battery data: $e');
    }
  }

  void _stopRefreshTimers() {
    _dataRefreshTimer?.cancel();
    _dataRefreshTimer = null;
  }

  void _setupListeners() {
    // Listen to connection state
    _connectionSubscription = _hardwareService.statusStream.listen((status) {
      if (mounted) {
        
        final isConnected = status == BleConnectionState.connected;
        setState(() {
          _isConnected = isConnected;
          if (!isConnected) {
            _batteryPercentage = null;
            _voltage = null;
            _isCharging = null;
            _rtcTimeDisplay = null;
            _rtcTimezone = null;
            _deviceName = null;

            _stopRefreshTimers();
          } else {

            // Restart timers when connected
            _startRefreshTimers();
          }
        });
      }
    });

    _devicePushSubscription =
        ref.read(bleBackgroundServiceProvider).devicePushStream.listen((event) {
      if (event['type'] != 'battery' || !mounted) return;
      final percent = event['percent'] as int?;
      final voltageMv = event['voltageMv'] as int?;
      final charging = event['charging'] as bool?;
      if (percent == null || voltageMv == null || charging == null) return;
      setState(() {
        _batteryPercentage = percent;
        _voltage = voltageMv / 1000.0;
        _isCharging = charging;
      });
    });

    // Set initial connection state
    setState(() {
      _isConnected = _hardwareService.isConnected;
    });
  }


  Future<void> _readRTCData() async {
    if (!_isConnected) {
      return;
    }

    try {
      final rtcTime = await _hardwareService.readRTC();
      if (mounted && rtcTime != null) {
        setState(() {
          _rtcTimeDisplay = rtcTime.toDisplayString();
          // Format timezone as just the hours (e.g., "-8" instead of "UTC-8:00")
          final tzHours = rtcTime.timezoneHours;
          _rtcTimezone = tzHours >= 0 ? '+$tzHours' : '$tzHours';
        });
      }
    } catch (e) {
      LoggingService.instance.log('Error reading RTC data: $e');
    }
  }

  Future<void> _readDeviceName() async {
    LoggingService.instance.log('Reading device name');
    if (!_isConnected) {
      return;
    }

    try {
      LoggingService.instance.log('Reading device name from device');
      final name = await _hardwareService.readDeviceName();
      LoggingService.instance.log('Device name read: $name');
      if (mounted) {
        setState(() {
          // Use read name if available, otherwise fall back to advertising name
          _deviceName = name ?? _hardwareService.deviceName;
        });
      }
    } catch (e) {
      LoggingService.instance.log('Error reading device name: $e');
      // Fall back to advertising name on error
      if (mounted) {
        setState(() {
          _deviceName = _hardwareService.deviceName;
        });
      }
    }
  }

  Future<void> _editDeviceName() async {
    if (!_isConnected || _isSettingDeviceName) {
      return;
    }

    // Show dialog with current name pre-filled
    final TextEditingController nameController = TextEditingController(text: _deviceName ?? '');
    
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Device Name'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            maxLength: 19,
            decoration: const InputDecoration(
              labelText: 'Device Name',
              hintText: 'Enter device name (max 19 characters)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              Navigator.of(context).pop(value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(nameController.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _isSettingDeviceName = true;
      });

      try {
        final success = await _hardwareService.writeDeviceName(result);
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Device name updated successfully')),
            );
            // Refresh device name
            await _readDeviceName();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update device name')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating device name: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSettingDeviceName = false;
          });
        }
      }
    }
  }

  Future<void> _setRTCTime() async {
    if (!_isConnected || _isSettingRTC) {
      return;
    }

    setState(() {
      _isSettingRTC = true;
    });

    try {
      final success = await _hardwareService.setRTCTimeNow();
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('RTC time set successfully')),
          );
          // Refresh RTC display
          await _readRTCData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to set RTC time')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting RTC time: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSettingRTC = false;
        });
      }
    }
  }

  Future<void> _pulseHaptic() async {
    if (!_isConnected || _isPulsingHaptic) {
      return;
    }

    setState(() {
      _isPulsingHaptic = true;
    });

    try {
      final success = await _hardwareService.triggerHapticPulse();
      if (mounted) {
        if (success) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('Haptic pulse triggered')),
          // );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to trigger haptic pulse')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error triggering haptic pulse: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPulsingHaptic = false;
        });
      }
    }
  }

  Future<void> _powerCycleDevice() async {
    if (!_isConnected || _isPowerCycling) {
      return;
    }

    setState(() {
      _isPowerCycling = true;
    });

    try {
      final success =
          await _hardwareService.sendCameraCommand(CameraCommand.powerCycle);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Power cycle sent — device will restart'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send power cycle')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending power cycle: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPowerCycling = false;
        });
      }
    }
  }

  Future<void> _triggerCamera() async {
    if (!_isConnected || _isTriggeringCamera) {
      return;
    }

    setState(() {
      _isTriggeringCamera = true;
    });

    try {
      final success = await _hardwareService.sendCameraCommand(CameraCommand.capture);
      if (mounted) {
        if (success) {
          // Silent success
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to trigger camera')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error triggering camera: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTriggeringCamera = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _stopRefreshTimers();
    _connectionSubscription?.cancel();
    _devicePushSubscription?.cancel();
    super.dispose();
  }

  /// Pairing / changing device: after **Forget**, or when there has never been a saved device.
  Future<void> _navigateToDeviceSelection() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const DeviceSelectionScreen()),
    );

    if (result == true && mounted) {
      await _loadPairedRemoteId();
      setState(() {
        _isConnected = _hardwareService.isConnected;
      });
    }
  }

  void _openPreferences() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Preferences'),
            surfaceTintColor: Colors.transparent,
          ),
          body: Center(
            child: Text(
              'Preferences coming soon',
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.gray500),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
  }

  Future<void> _disconnectBle() async {
    ref.read(bleBackgroundServiceProvider).stopBle();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disconnected from device')),
    );
  }

  void _onDeviceCardTap() {
    if (_isConnected) {
      _showDeviceActionsSheet();
    }
  }

  void _showDeviceActionsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
                border: Border.all(color: AppColors.gray100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: RefLayout.sheetHandleWidth,
                      height: RefLayout.sheetHandleHeight,
                      decoration: BoxDecoration(
                        color: AppColors.gray200,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DeviceSheetButton(
                      label: 'Edit Name',
                      filled: false,
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(_editDeviceName());
                      },
                    ),
                    const SizedBox(height: 8),
                    _DeviceSheetButton(
                      label: 'Restart',
                      filled: false,
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(_powerCycleDevice());
                      },
                    ),
                    const SizedBox(height: 8),
                    _DeviceSheetButton(
                      label: 'Forget',
                      filled: false,
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(_forgetPairedDevice());
                      },
                    ),
                    const SizedBox(height: 8),
                    _DeviceSheetButton(
                      label: 'Disconnect',
                      filled: true,
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(_disconnectBle());
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _forgetPairedDevice() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forget this Nexus?'),
        content: const Text(
          'This phone will stop connecting to the saved device. '
          'The peripheral may still expect its bonded phone until you reset it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _hardwareService.forgetPairedDevice();
    if (mounted) {
      await _loadPairedRemoteId();
      setState(() {
        _isConnected = _hardwareService.isConnected;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved device cleared')),
      );
    }
  }

  Future<void> _reconnectPairedDevice() async {
    final id = _pairedRemoteId;
    if (id == null || id.isEmpty || !mounted) return;
    ref.read(bleBackgroundServiceProvider).applyPairedRemoteId(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connecting…')),
    );
  }

  String get _rememberedDisplayName {
    final n = (_deviceName ?? _hardwareService.deviceName)?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Your Nexus';
  }

  @override
  Widget build(BuildContext context) {
    final hasPairedDevice =
        _pairedRemoteId != null && _pairedRemoteId!.isNotEmpty;
    final displayName =
        _deviceName ?? _hardwareService.deviceName ?? 'Not connected';

    String rtcSubtitle = '—';
    if (_isConnected && _rtcTimeDisplay != null) {
      final parts = _rtcTimeDisplay!.split('\n');
      if (parts.length >= 2) {
        final tz = _rtcTimezone != null ? ' (UTC$_rtcTimezone)' : '';
        rtcSubtitle = '${parts[0].trim()} · ${parts[1].trim()}$tz';
      } else {
        rtcSubtitle = _rtcTimeDisplay!.replaceAll('\n', ' ');
      }
    }

    final drawerWidth = math.min(
      252.0,
      MediaQuery.sizeOf(context).width * 0.72,
    );

    return Scaffold(
      backgroundColor: AppColors.gray50,
      endDrawer: Drawer(
        width: drawerWidth,
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  'Menu',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: AppColors.gray900,
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.gray100),
              ListTile(
                leading: Icon(Icons.settings_outlined, color: AppColors.gray600, size: 22),
                title: Text(
                  'Preferences',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray900,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _openPreferences();
                },
              ),
              ListTile(
                leading: Icon(Icons.logout_rounded, color: AppColors.gray600, size: 22),
                title: Text(
                  'Log out',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray900,
                  ),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _logout();
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text('Nexus', style: refAppBarTitleLarge()),
        surfaceTintColor: Colors.transparent,
        actions: [
          Builder(
            builder: (scaffoldCtx) {
              return IconButton(
                icon: const Icon(Icons.menu, color: AppColors.gray600),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(scaffoldCtx).openEndDrawer(),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_isConnected) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                RefLayout.p4,
                RefLayout.p4,
                RefLayout.p4,
                96,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DeviceCard(
                    displayName: displayName,
                    pairedOffline: false,
                    isRenaming: _isSettingDeviceName,
                    onCardTap: _onDeviceCardTap,
                    onVibrate:
                        _isConnected && !_isPulsingHaptic ? _pulseHaptic : null,
                    pulseBusy: _isPulsingHaptic,
                  ),
                  const SizedBox(height: RefLayout.gap4),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _MetricTile(
                            label: 'Battery',
                            trailingIcon:
                                (_isConnected && _isCharging == true)
                                    ? Icon(
                                        Icons.bolt_rounded,
                                        size: 18,
                                        color: AppColors.green500,
                                      )
                                    : Icon(
                                        Icons.bolt_rounded,
                                        size: 18,
                                        color: AppColors.gray400,
                                      ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  _isConnected && _batteryPercentage != null
                                      ? '$_batteryPercentage'
                                      : '—',
                                  style: GoogleFonts.inter(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.5,
                                    color: _isConnected &&
                                            _batteryPercentage != null
                                        ? AppColors.gray900
                                        : AppColors.gray400,
                                  ),
                                ),
                                Text(
                                  '%',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: AppColors.gray500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: RefLayout.gap4),
                        Expanded(
                          child: _MetricTile(
                            label: 'Voltage',
                            trailingIcon: Icon(
                              Icons.show_chart_rounded,
                              size: 18,
                              color: AppColors.gray400,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  _isConnected && _voltage != null
                                      ? _voltage!.toStringAsFixed(2)
                                      : '—',
                                  style: GoogleFonts.inter(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.5,
                                    color: _isConnected && _voltage != null
                                        ? AppColors.gray900
                                        : AppColors.gray400,
                                  ),
                                ),
                                Text(
                                  ' v',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: AppColors.gray500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: RefLayout.gap4),
                  Container(
                    padding: const EdgeInsets.all(RefLayout.p4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
                      border: Border.all(color: AppColors.gray100),
                      boxShadow: refCardShadow,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Device Clock (RTC)',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.gray500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rtcSubtitle,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.gray900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: AppColors.orange50,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _isConnected && !_isSettingRTC
                                ? _setRTCTime
                                : null,
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: _isSettingRTC
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      Icons.refresh_rounded,
                                      color: _isConnected
                                          ? AppColors.orange600
                                          : AppColors.gray400,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: RefLayout.gap4),
                  CameraSection(
                    isConnected: _isConnected,
                    captureInProgress: _isTriggeringCamera,
                    onCapture: _triggerCamera,
                  ),
                ],
              ),
            );
          }
          if (hasPairedDevice) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                RefLayout.p4,
                RefLayout.p4,
                RefLayout.p4,
                96,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DeviceCard(
                    displayName: _rememberedDisplayName,
                    pairedOffline: true,
                    isRenaming: false,
                    onVibrate: null,
                    pulseBusy: false,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _reconnectPairedDevice,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orange600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      shadowColor:
                          AppColors.orange600.withValues(alpha: 0.35),
                    ),
                    icon: const Icon(Icons.bluetooth_rounded, size: 22),
                    label: Text(
                      'Connect',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => unawaited(_forgetPairedDevice()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gray600,
                      side: const BorderSide(color: AppColors.gray200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Forget Device',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          final minH = math.max(0.0, constraints.maxHeight - 120);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(RefLayout.p4, 0, RefLayout.p4, 96),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minH),
              child: Center(
                child: _NoHardwareEmptyState(
                  onFindDevice: () => unawaited(_navigateToDeviceSelection()),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.displayName,
    required this.pairedOffline,
    required this.isRenaming,
    this.onCardTap,
    required this.onVibrate,
    required this.pulseBusy,
  });

  final String displayName;
  final bool pairedOffline;
  final bool isRenaming;
  final VoidCallback? onCardTap;
  final VoidCallback? onVibrate;
  final bool pulseBusy;

  @override
  Widget build(BuildContext context) {
    final nameBlock = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gray900,
                ),
              ),
            ),
            if (!pairedOffline && isRenaming) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );

    Widget leadingNameAndTap() {
      if (pairedOffline) {
        return Expanded(child: nameBlock);
      }
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onCardTap,
          child: nameBlock,
        ),
      );
    }

    Widget trailing() {
      if (pairedOffline) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.gray400),
            const SizedBox(width: 4),
            Text(
              'Offline',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.gray400,
              ),
            ),
          ],
        );
      }
      return Material(
        color: AppColors.gray50,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onVibrate,
          child: SizedBox(
            width: 32,
            height: 32,
            child: pulseBusy
                ? const Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.vibration_rounded,
                    size: 18,
                    color: onVibrate != null
                        ? AppColors.gray600
                        : AppColors.gray400,
                  ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(RefLayout.p4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        border: Border.all(color: AppColors.gray100),
        boxShadow: refCardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _DownTriangleBadge(offline: pairedOffline),
          const SizedBox(width: 12),
          leadingNameAndTap(),
          trailing(),
        ],
      ),
    );
  }
}

class _NoHardwareEmptyState extends StatelessWidget {
  const _NoHardwareEmptyState({required this.onFindDevice});

  final VoidCallback onFindDevice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.gray100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bluetooth_disabled_rounded,
              size: 38,
              color: AppColors.gray400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Device Paired',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your Nexus wearable to start talking with your AI.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 1.4,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onFindDevice,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              shadowColor: AppColors.orange600.withValues(alpha: 0.35),
            ),
            icon: const Icon(Icons.bluetooth_searching_rounded, size: 22),
            label: Text(
              'Find Device',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.child,
    this.trailingIcon,
  });

  final String label;
  final Widget child;
  final Widget? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(RefLayout.p4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        border: Border.all(color: AppColors.gray100),
        boxShadow: refCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.gray500,
                ),
              ),
              if (trailingIcon != null) trailingIcon!,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DeviceSheetButton extends StatelessWidget {
  const _DeviceSheetButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gray900,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.gray900,
          side: const BorderSide(color: AppColors.gray200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }
}

class _DownTriangleBadge extends StatelessWidget {
  const _DownTriangleBadge({this.offline = false});

  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: offline ? AppColors.gray100 : AppColors.orange50,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: CustomPaint(
        size: const Size(24, 24),
        painter: _DownTrianglePainter(offline: offline),
      ),
    );
  }
}

class _DownTrianglePainter extends CustomPainter {
  const _DownTrianglePainter({this.offline = false});

  final bool offline;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = offline ? const Color(0xFF9CA3AF) : const Color(0xFF171717);
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 5 / 24, h * 6.5 / 24)
      ..lineTo(w * 19 / 24, h * 6.5 / 24)
      ..lineTo(w * 12 / 24, h * 18.2 / 24)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DownTrianglePainter oldDelegate) {
    return oldDelegate.offline != offline;
  }
}

