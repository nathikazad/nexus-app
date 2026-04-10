import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/services/hardware_service/camera_command.dart';
import 'package:nexus_voice_assistant/services/hardware_service/hardware_service.dart';
import 'package:nexus_voice_assistant/services/logging_service.dart';

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


/// BLE-connected auto photo-record controls: status, interval dropdown, start/stop.
///
/// Refreshes status after record commands (start/stop/interval); single-shot capture
/// does not affect record state on the device.
class CameraSection extends ConsumerStatefulWidget {
  const CameraSection({
    super.key,
    required this.isConnected,
    this.titleTrailing,
  });

  final bool isConnected;

  /// Shown to the right of the "Photo record" title (e.g. capture button).
  final Widget? titleTrailing;

  @override
  ConsumerState<CameraSection> createState() => CameraSectionState();
}

class CameraSectionState extends ConsumerState<CameraSection>
    with WidgetsBindingObserver {
  bool? _recording;
  int _selectedPeriodSec = 60;
  bool _busy = false;

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
      LoggingService.instance.log('PhotoRecordSection: initial read failed: $e');
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.titleTrailing != null) ...[
          widget.titleTrailing!,
          const SizedBox(width: 8),
        ],
        IconButton(
          onPressed: canInteract
              ? (isRecording ? _stop : _start)
              : null,
          icon: Icon(
            isRecording ? Icons.pause : Icons.play_arrow,
            size: 22,
            color: Colors.grey[800],
          ),
          tooltip: isRecording ? 'Stop photo record' : 'Start photo record',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              isDense: true,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: kPhotoRecordPeriodOptions.contains(_selectedPeriodSec)
                    ? _selectedPeriodSec
                    : _nearestPhotoRecordPeriodOption(_selectedPeriodSec),
                items: kPhotoRecordPeriodOptions
                    .map(
                    (s) => DropdownMenuItem<int>(
                      value: s,
                      child: Text('$s', softWrap: false, overflow: TextOverflow.visible),
                    ),
                    )
                    .toList(),
              onChanged: canInteract ? _onPeriodChanged : null,
            ),
          ),
        ),
        ),
        if (_busy) ...[
          const SizedBox(width: 8),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ],
    );
  }
}
