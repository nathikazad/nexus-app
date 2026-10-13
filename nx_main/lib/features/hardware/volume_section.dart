import 'dart:async';
import 'package:flutter/material.dart';

class VolumeSection extends StatefulWidget {
  const VolumeSection(
      {super.key,
      required this.isConnected,
      required this.read,
      required this.write});
  final bool isConnected;
  final Future<List<int>?> Function() read;
  final Future<bool> Function(int, int) write;
  @override
  State<VolumeSection> createState() => _VolumeSectionState();
}

class _VolumeSectionState extends State<VolumeSection> {
  String _sides(int mask) => const ['None', 'Left', 'Right', 'Both'][mask & 3];
  Timer? _timer;
  List<int>? _values;
  bool _busy = false, _dragging = false;
  int _generation = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant VolumeSection old) {
    super.didUpdateWidget(old);
    if (old.isConnected != widget.isConnected) {
      _generation++;
      _values = null;
      _busy = false;
      _dragging = false;
      _refresh();
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!widget.isConnected || _busy || _dragging) return;
    final generation = _generation;
    _busy = true;
    final value = await widget.read();
    if (!mounted || generation != _generation) return;
    setState(() {
      _busy = false;
      if (value != null &&
          value.length == 7 &&
          value[0] == 2 &&
          value[1] <= 100 &&
          value[2] <= 100 &&
          value[3] <= 2) {
        _values = List.of(value);
        _error = null;
      } else {
        _values = null;
        _error = 'Volume unavailable. Check the connection and firmware.';
      }
    });
  }

  Future<void> _write(int output, double value) async {
    final generation = _generation;
    setState(() {
      _dragging = false;
      _busy = true;
    });
    final ok = await widget.write(output, value.round());
    if (!mounted || generation != _generation) return;
    setState(() {
      _busy = false;
      _error = ok ? null : 'Could not change volume';
    });
    if (ok) await _refresh();
  }

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Output volume',
                style: Theme.of(context).textTheme.titleMedium),
            Text(!widget.isConnected
                ? 'Headset: necklace disconnected'
                : _values == null
                    ? 'Headset: checking…'
                    : 'Headset connected: ${_sides(_values![4])}${_values![6] > 0 ? " (identifying ${_values![6]} bud)" : ""}'),
            if (widget.isConnected && _values != null)
              Text('Ready for audio: ${_sides(_values![5])}'),
            for (var output = 0; output < 2; output++) ...[
              Text(
                  '${output == 0 ? "Speaker" : "Headset"}: ${_values == null ? "—" : "${_values![output + 1]}%"}'),
              Slider(
                  value: (_values?[output + 1] ?? 0).toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChangeStart: (_) {
                    _generation++;
                    _busy = false;
                    _dragging = true;
                  },
                  onChanged: widget.isConnected && _values != null && !_busy
                      ? (v) => setState(() => _values![output + 1] = v.round())
                      : null,
                  onChangeEnd: (v) => _write(output, v)),
            ],
            if (_error != null) Text(_error!),
            if (_values != null && _error == null)
              Text(_values![3] == 0
                  ? 'Saved on necklace'
                  : _values![3] == 1
                      ? 'Applied; saving after audio finishes…'
                      : 'Applied, but saving failed. Adjust again to retry.'),
          ])));
}
