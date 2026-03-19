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

const Duration _kStatusAfterCommandDelay = Duration(seconds: 3);
const Duration _kStatusPollInterval = Duration(seconds: 30);

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

class CameraSectionState extends ConsumerState<CameraSection> {
  bool? _recording;
  int? _periodSec;
  int _selectedPeriodSec = 60;
  bool _busy = false;

  Timer? _pollTimer;
  Timer? _postCmdTimer;

  HardwareService get _hardware => ref.read(hardwareServiceProvider);

  @override
  void initState() {
    super.initState();
    if (widget.isConnected) {
      _onBecameConnected();
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
    _cancelTimers();
    super.dispose();
  }

  void _cancelTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _postCmdTimer?.cancel();
    _postCmdTimer = null;
  }

  void _onBecameConnected() {
    _cancelTimers();
    unawaited(_readStatus());
    _pollTimer = Timer.periodic(_kStatusPollInterval, (_) => _readStatus());
  }

  void _onBecameDisconnected() {
    _cancelTimers();
    if (mounted) {
      setState(() {
        _recording = null;
        _periodSec = null;
      });
    }
  }

  /// Re-read status shortly after a record command (start/stop/interval).
  void _scheduleStatusRefreshAfterCommand() {
    if (!widget.isConnected || !mounted) return;
    _postCmdTimer?.cancel();
    _postCmdTimer = Timer(_kStatusAfterCommandDelay, () {
      _postCmdTimer = null;
      if (mounted) unawaited(_readStatus());
    });
  }

  Future<void> _readStatus() async {
    if (!widget.isConnected) return;
    try {
      final status = await _hardware.readCameraRecordStatus();
      if (!mounted || status == null) return;
      setState(() {
        _recording = status.isRecording;
        _periodSec = status.periodSec;
        _selectedPeriodSec = kPhotoRecordPeriodOptions.contains(status.periodSec)
            ? status.periodSec
            : _nearestPhotoRecordPeriodOption(status.periodSec);
      });
    } catch (e) {
      LoggingService.instance.log('PhotoRecordSection: read status failed: $e');
    }
  }

  Future<void> _start() async {
    if (!widget.isConnected || _busy) return;
    setState(() => _busy = true);
    try {
      LoggingService.instance.log('PhotoRecord: sending setRecordPeriod(${_selectedPeriodSec})');
      final periodOk = await _hardware.sendCameraCommand(
        CameraCommand.setRecordPeriod,
        period: _selectedPeriodSec,
      );
      LoggingService.instance.log('PhotoRecord: setRecordPeriod result=$periodOk');
      if (!periodOk) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to set photo record interval')),
          );
        }
        return;
      }
      LoggingService.instance.log('PhotoRecord: sending startRecord');
      final startOk = await _hardware.sendCameraCommand(CameraCommand.startRecord);
      LoggingService.instance.log('PhotoRecord: startRecord result=$startOk');
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
      _scheduleStatusRefreshAfterCommand();
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
      _scheduleStatusRefreshAfterCommand();
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
      _scheduleStatusRefreshAfterCommand();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Photo record',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              if (widget.titleTrailing != null) ...[
                const SizedBox(width: 4),
                widget.titleTrailing!,
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          !widget.isConnected
              ? '--'
              : _recording == null || _periodSec == null
                  ? '--'
                  : '${_recording! ? 'On' : 'Off'} · every ${_periodSec!} s',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: widget.isConnected &&
                    _recording != null &&
                    _periodSec != null
                ? Colors.teal
                : Colors.grey,
          ),
        ),
        if (widget.isConnected) ...[
          const SizedBox(height: 16),
          Text(
            'Interval',
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                            child: Text('$s seconds'),
                          ),
                        )
                        .toList(),
                    onChanged: _busy ? null : _onPeriodChanged,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: !_busy && (_recording != true) ? _start : null,
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text('Start'),
              ),
              const SizedBox(width: 16),
              FilledButton.tonalIcon(
                onPressed: !_busy && (_recording == true) ? _stop : null,
                icon: const Icon(Icons.stop, size: 20),
                label: const Text('Stop'),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 8),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ],
    );
  }
}
