import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'desires.dart';

class Listening extends ChangeNotifier {
  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Tape? tape;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool playing = false;
  bool loading = false;
  double speed = 1;
  String? error;
  int _generation = 0;
  bool _disposed = false;
  void _update() {
    if (!_disposed) notifyListeners();
  }

  AudioPlayer get player {
    if (_player != null) return _player!;
    final p = _player = AudioPlayer();
    _subscriptions.add(
      p.positionStream.listen((v) {
        position = v;
        _update();
      }),
    );
    _subscriptions.add(
      p.durationStream.listen((v) {
        duration = v ?? Duration.zero;
        _update();
      }),
    );
    _subscriptions.add(
      p.playerStateStream.listen((v) {
        playing = v.playing && v.processingState != ProcessingState.completed;
        loading =
            v.processingState == ProcessingState.loading ||
            v.processingState == ProcessingState.buffering;
        _update();
      }),
    );
    _subscriptions.add(
      p.errorStream.listen((e) {
        error = 'The recording could not be played. Please try again.';
        loading = false;
        _update();
      }),
    );
    return p;
  }

  Future<void> open(Tape item) async {
    if (item.audioAsset == null) return;
    final request = ++_generation;
    error = null;
    try {
      if (tape?.id != item.id) {
        tape = item;
        loading = true;
        position = Duration.zero;
        duration = Duration.zero;
        _update();
        await player.setAsset(item.audioAsset!);
      }
      if (_disposed || request != _generation) return;
      await player.setSpeed(speed);
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      unawaited(_play());
    } catch (_) {
      if (request == _generation && !_disposed) {
        loading = false;
        error = 'The recording could not be loaded. Please try again.';
        _update();
      }
    }
  }

  Future<void> _play() async {
    try {
      await player.play();
    } catch (_) {
      if (!_disposed) {
        error = 'Playback failed. Please try again.';
        _update();
      }
    }
  }

  Future<void> toggle() async {
    if (playing) {
      await player.pause();
    } else if (tape != null) {
      await open(tape!);
    }
  }

  Future<void> seek(Duration value) => player.seek(
    Duration(
      milliseconds: value.inMilliseconds.clamp(0, duration.inMilliseconds),
    ),
  );
  Future<void> skip(int seconds) => seek(position + Duration(seconds: seconds));
  Future<void> changeSpeed(double value) async {
    speed = value;
    await player.setSpeed(value);
    _update();
  }

  Future<void> close() async {
    ++_generation;
    tape = null;
    playing = false;
    loading = false;
    error = null;
    _update();
    await _player?.stop();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(_player?.dispose());
    super.dispose();
  }
}

class ListeningBar extends StatelessWidget {
  const ListeningBar({super.key, required this.listening});
  final Listening listening;
  String time(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: listening,
    builder: (context, _) {
      if (listening.tape == null) return const SizedBox.shrink();
      final total = listening.duration.inMilliseconds.toDouble();
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Material(
                color: Colors.white,
                elevation: 5,
                shadowColor: Colors.black12,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              listening.tape!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close player',
                            onPressed: listening.close,
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                      if (listening.error != null)
                        Text(
                          listening.error!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      Row(
                        children: [
                          Text(
                            time(listening.position),
                            style: const TextStyle(fontSize: 11),
                          ),
                          Expanded(
                            child: Slider(
                              value: listening.position.inMilliseconds
                                  .toDouble()
                                  .clamp(0, total),
                              max: total > 0 ? total : 1,
                              onChanged: total > 0
                                  ? (v) => listening.seek(
                                      Duration(milliseconds: v.toInt()),
                                    )
                                  : null,
                            ),
                          ),
                          Text(
                            time(listening.duration),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => listening.skip(-15),
                            child: const Text('−15s'),
                          ),
                          IconButton.filled(
                            tooltip: listening.playing ? 'Pause' : 'Play',
                            onPressed: listening.loading
                                ? null
                                : listening.toggle,
                            icon: listening.loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    listening.playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                  ),
                          ),
                          TextButton(
                            onPressed: () => listening.skip(15),
                            child: const Text('+15s'),
                          ),
                          PopupMenuButton<double>(
                            tooltip: 'Playback speed',
                            initialValue: listening.speed,
                            onSelected: listening.changeSpeed,
                            itemBuilder: (_) => [0.75, 1.0, 1.25]
                                .map(
                                  (v) => PopupMenuItem(
                                    value: v,
                                    child: Text('$v×'),
                                  ),
                                )
                                .toList(),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text('${listening.speed}×'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
