import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_voice_assistant/core/layout/layout.dart';
import 'package:nexus_voice_assistant/core/logging/logging_service.dart';
import 'package:nexus_voice_assistant/core/theme/app_theme.dart';
import 'package:nexus_voice_assistant/data/hardware/camera_command.dart';
import 'package:nexus_voice_assistant/data/hardware/hardware_service.dart';
import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nexus_voice_assistant/domain/ble/camera_record_status.dart';

/// Allowed photo-record intervals (seconds) for the UI dropdown.
const List<int> kPhotoRecordPeriodOptions = [
  20,
  30,
  40,
  50,
  60,
  120,
  150,
  240,
  300,
];

int _nearestPhotoRecordPeriodOption(int deviceSec) {
  var best = kPhotoRecordPeriodOptions.first;
  var bestDiff = (deviceSec - best).abs();
  for (final o in kPhotoRecordPeriodOptions) {
    final d = (deviceSec - o).abs();
    if (d < bestDiff) {
      best = o;
      bestDiff = d;
    }
  }
  return best;
}

String _formatPeriodLabel(int sec) {
  if (sec >= 60 && sec % 60 == 0) {
    final m = sec ~/ 60;
    return m == 1 ? '1 min' : '$m min';
  }
  return '$sec sec';
}

/// BLE-connected camera card: capture FAB, expandable photo-record controls.
class CameraSection extends ConsumerStatefulWidget {
  const CameraSection({
    super.key,
    required this.isConnected,
    required this.onCapture,
    this.captureInProgress = false,
  });

  final bool isConnected;

  /// Single-shot capture (does not change record state on device).
  final VoidCallback onCapture;

  final bool captureInProgress;

  @override
  ConsumerState<CameraSection> createState() => CameraSectionState();
}

class CameraSectionState extends ConsumerState<CameraSection>
    with WidgetsBindingObserver {
  bool? _recording;
  int _selectedPeriodSec = 60;
  bool _busy = false;
  bool _advancedExpanded = false;

  StreamSubscription<CameraRecordStatus>? _cameraStatusSubscription;

  HardwareService get _hardware => ref.read(hardwareServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isConnected) {
      _onBecameConnected();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && widget.isConnected) {
      unawaited(_readInitialStatus());
    }
  }

  @override
  void didUpdateWidget(CameraSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isConnected && widget.isConnected) {
      _onBecameConnected();
    } else if (oldWidget.isConnected && !widget.isConnected) {
      _onBecameDisconnected();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraStatusSubscription?.cancel();
    super.dispose();
  }

  void _onBecameConnected() {
    _cameraStatusSubscription?.cancel();
    _cameraStatusSubscription = _hardware.cameraStatusStream.listen(_onCameraStatus);
    unawaited(_readInitialStatus());
  }

  void _onBecameDisconnected() {
    _cameraStatusSubscription?.cancel();
    _cameraStatusSubscription = null;
    if (mounted) {
      setState(() {
        _recording = null;
      });
    }
  }

  void _onCameraStatus(CameraRecordStatus status) {
    if (!mounted) return;
    setState(() {
      _recording = status.isRecording;
      _selectedPeriodSec = kPhotoRecordPeriodOptions.contains(status.periodSec)
          ? status.periodSec
          : _nearestPhotoRecordPeriodOption(status.periodSec);
    });
  }

  Future<void> _readInitialStatus() async {
    if (!widget.isConnected) return;
    try {
      final status = await _hardware.readCameraRecordStatus();
      if (!mounted || status == null) return;
      _onCameraStatus(status);
    } catch (e) {
      LoggingService.instance.log('CameraSection: initial read failed: $e');
    }
  }

  Future<void> _start() async {
    if (!widget.isConnected || _busy) return;
    setState(() => _busy = true);
    try {
      final periodOk = await _hardware.sendCameraCommand(
        CameraCommand.setRecordPeriod,
        period: _selectedPeriodSec,
      );
      if (!periodOk) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to set photo record interval')),
          );
        }
        return;
      }
      final startOk = await _hardware.sendCameraCommand(CameraCommand.startRecord);
      if (mounted && !startOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start photo record')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo record: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    if (!widget.isConnected || _busy) return;
    setState(() => _busy = true);
    try {
      final ok = await _hardware.sendCameraCommand(CameraCommand.stopRecord);
      if (mounted && !ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to stop photo record')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo record: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onPeriodChanged(int? value) async {
    if (value == null || !widget.isConnected) return;
    setState(() => _selectedPeriodSec = value);
    if (_recording != true) return;

    setState(() => _busy = true);
    try {
      final ok = await _hardware.sendCameraCommand(
        CameraCommand.setRecordPeriod,
        period: value,
      );
      if (mounted && !ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update interval')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Interval: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canInteract = widget.isConnected && !_busy;
    final isRecording = _recording == true;
    final subtitle = !widget.isConnected
        ? 'Not connected'
        : '${isRecording ? 'Recording' : 'Not Recording'} · ${_formatPeriodLabel(_selectedPeriodSec)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        border: Border.all(color: AppColors.gray100),
        boxShadow: refCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _advancedExpanded = !_advancedExpanded),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Camera',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.gray900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Material(
                color: AppColors.orange600,
                elevation: 3,
                shadowColor: AppColors.orange600.withValues(alpha: 0.35),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: canInteract && !widget.captureInProgress ? widget.onCapture : null,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: widget.captureInProgress
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(height: 1, color: AppColors.gray100),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Auto Recording',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: AppColors.gray600,
                            ),
                          ),
                          Switch.adaptive(
                            value: isRecording,
                            onChanged: canInteract
                                ? (v) {
                                    if (v) {
                                      unawaited(_start());
                                    } else {
                                      unawaited(_stop());
                                    }
                                  }
                                : null,
                            activeTrackColor: AppColors.orange600,
                            thumbColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.white;
                              }
                              return null;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Interval',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: AppColors.gray600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.gray50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isDense: true,
                                value: kPhotoRecordPeriodOptions.contains(_selectedPeriodSec)
                                    ? _selectedPeriodSec
                                    : _nearestPhotoRecordPeriodOption(_selectedPeriodSec),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.gray900,
                                ),
                                iconEnabledColor: AppColors.gray500,
                                iconSize: 18,
                                dropdownColor: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                items: kPhotoRecordPeriodOptions
                                    .map(
                                      (s) => DropdownMenuItem<int>(
                                        value: s,
                                        child: Text(
                                          _formatPeriodLabel(s),
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: AppColors.gray900,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: canInteract ? _onPeriodChanged : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                crossFadeState: _advancedExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
        ],
      ),
    );
  }
}
