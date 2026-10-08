import 'dart:async';
import 'package:flutter/material.dart';

class NecklaceAudioStatus {
  NecklaceAudioStatus(List<int> bytes) {
    if (bytes.length != 18 || bytes[17] != 1)
      throw const FormatException('Unsupported audio status');
    background = bytes[1];
    live = bytes[16];
    seconds = bytes[12] | bytes[13] << 8 | bytes[14] << 16 | bytes[15] << 24;
  }
  late final int background, live, seconds;
  String get elapsed =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class AudioSection extends StatefulWidget {
  const AudioSection(
      {super.key,
      required this.isConnected,
      required this.readStatus,
      required this.command});
  final bool isConnected;
  final Future<List<int>?> Function() readStatus;
  final Future<bool> Function(int) command;
  @override
  State<AudioSection> createState() => _AudioSectionState();
}

class _AudioSectionState extends State<AudioSection> {
  Timer? _timer;
  NecklaceAudioStatus? _status;
  bool _reading = false, _sending = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_reading || _sending) return;
    _reading = true;
    NecklaceAudioStatus? next;
    try {
      if (widget.isConnected) {
        final bytes = await widget.readStatus();
        if (bytes != null) next = NecklaceAudioStatus(bytes);
      }
    } catch (_) {/* Unavailable is distinct from idle. */}
    if (mounted) setState(() => _status = next);
    _reading = false;
  }

  Future<void> _send(int operation) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    bool ok = false;
    try {
      ok = await widget.command(operation);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = ok
          ? null
          : 'Command not confirmed. Check connection and retry Stop if needed.';
    });
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.isConnected ? _status : null;
    final enabled = widget.isConnected && !_sending;
    final live = s?.live == 2;
    final bg = s?.background;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Talk to AI',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(s == null || s.live == 0
                      ? 'Status unavailable'
                      : live
                          ? 'Recording'
                          : 'Idle'),
                  FilledButton(
                      onPressed: enabled ? () => _send(live ? 3 : 4) : null,
                      child:
                          Text(live ? 'Stop & send' : 'Talk through necklace')),
                  if (!live)
                    TextButton(
                        onPressed: enabled ? () => _send(3) : null,
                        child: const Text('Stop & send existing recording')),
                  const Divider(),
                  const Text('Background audio',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(s == null
                      ? 'Status unavailable'
                      : '${switch (bg) {
                          0 => 'Idle',
                          1 => 'Starting',
                          2 => 'Recording',
                          3 => 'Stopping',
                          _ => 'Error'
                        }}${bg == 2 || bg == 3 ? ' · ${s.elapsed}' : ''}'),
                  FilledButton(
                      onPressed: enabled
                          ? () => _send(bg == 1 || bg == 2 || bg == 3 ? 0 : 1)
                          : null,
                      child: Text(bg == 1 || bg == 2 || bg == 3
                          ? 'Stop recording'
                          : 'Start recording')),
                  if (s == null)
                    TextButton(
                        onPressed: enabled ? () => _send(0) : null,
                        child:
                            const Text('Stop existing background recording')),
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                ])));
  }
}
