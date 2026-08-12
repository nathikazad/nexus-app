import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/domain/card/card_audio_repository.dart';

class LanguageAudioControls extends StatefulWidget {
  const LanguageAudioControls({
    super.key,
    required this.audioUrl,
    required this.repository,
    this.autoPlay = true,
  });

  final String audioUrl;
  final CardAudioRepository repository;
  final bool autoPlay;

  @override
  State<LanguageAudioControls> createState() => _LanguageAudioControlsState();
}

class PronunciationButton extends StatefulWidget {
  const PronunciationButton({
    super.key,
    required this.audioUrl,
    required this.repository,
  });

  final String audioUrl;
  final CardAudioRepository repository;

  @override
  State<PronunciationButton> createState() => _PronunciationButtonState();
}

class _PronunciationButtonState extends State<PronunciationButton> {
  final AudioPlayer _player = AudioPlayer();
  bool _loading = false;
  bool _playing = false;

  Future<void> _play() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final bytes = await widget.repository.fetch(widget.audioUrl);
      await _player.play(languageAudioSource(bytes));
      if (mounted) setState(() => _playing = true);
      await _player.onPlayerComplete.first;
    } catch (error, stackTrace) {
      debugPrint(
        '[nx_cards audio] compact playback failed url=${widget.audioUrl} '
        'error=$error\n$stackTrace',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _playing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    key: const ValueKey<String>('pronunciation-button'),
    tooltip: _playing ? 'Playing pronunciation' : 'Play pronunciation',
    onPressed: _loading ? null : _play,
    icon: _loading
        ? const SizedBox.square(
            dimension: 17,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(_playing ? Icons.volume_up_rounded : Icons.play_arrow_rounded),
  );
}

class _LanguageAudioControlsState extends State<LanguageAudioControls> {
  static const _rates = <double>[0.25, 0.5, 1];

  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<Object?>> _subscriptions = [];

  Uint8List? _bytes;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  PlayerState _state = PlayerState.stopped;
  double _rate = 1;
  bool _loading = false;
  bool _sourceReady = false;
  bool _draggingSlider = false;
  String? _error;

  bool get _isPlaying => _state == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _subscriptions.addAll([
      _player.onDurationChanged.listen((duration) {
        if (mounted) setState(() => _duration = duration);
      }),
      _player.onPositionChanged.listen((position) {
        if (mounted && !_draggingSlider) {
          setState(() => _position = position);
        }
      }),
      _player.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _state = state);
      }),
      _player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _state = PlayerState.completed;
          _position = _duration;
        });
      }),
    ]);
    unawaited(_prepare(autoPlay: widget.autoPlay));
  }

  Future<bool> _prepare({required bool autoPlay}) async {
    if (_sourceReady) {
      if (autoPlay) await _resume();
      return true;
    }
    if (_loading) return false;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _bytes ??= await widget.repository.fetch(widget.audioUrl);
      // Keep the prepared source after completion so pronunciation can be
      // replayed without downloading or preparing it again.
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setSource(languageAudioSource(_bytes!));
      _sourceReady = true;
      if (autoPlay) await _resume();
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        '[nx_cards audio] load failed url=${widget.audioUrl} '
        'error=$error\n$stackTrace',
      );
      if (mounted) {
        setState(() => _error = 'Could not load pronunciation');
      }
      return false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resume() async {
    if (_duration > Duration.zero && _position >= _duration) {
      await _player.seek(Duration.zero);
      if (mounted) setState(() => _position = Duration.zero);
    }
    await _player.resume();
    await _player.setPlaybackRate(_rate);
  }

  Future<void> _togglePlayback() async {
    if (_loading) return;
    try {
      setState(() => _error = null);
      if (_isPlaying) {
        await _player.pause();
        return;
      }
      if (!await _prepare(autoPlay: false)) return;
      await _resume();
    } catch (error, stackTrace) {
      debugPrint(
        '[nx_cards audio] playback failed url=${widget.audioUrl} '
        'error=$error\n$stackTrace',
      );
      if (mounted) setState(() => _error = 'Could not play pronunciation');
    }
  }

  Future<void> _seek(double milliseconds) async {
    if (!_sourceReady) return;
    try {
      final position = Duration(milliseconds: milliseconds.round());
      await _player.seek(position);
      if (mounted) setState(() => _position = position);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not seek audio');
    } finally {
      if (mounted) setState(() => _draggingSlider = false);
    }
  }

  Future<void> _changeRate(double rate) async {
    if (_rate == rate) return;
    final previousRate = _rate;
    setState(() {
      _rate = rate;
      _error = null;
    });
    if (!_sourceReady || !_isPlaying) return;
    try {
      await _player.setPlaybackRate(rate);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _rate = previousRate;
        _error = '${formatPlaybackRate(rate)} is unavailable on this device';
      });
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalMilliseconds = _duration.inMilliseconds.toDouble();
    final positionMilliseconds = _position.inMilliseconds
        .clamp(0, _duration.inMilliseconds)
        .toDouble();

    return Semantics(
      label: 'Pronunciation audio',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: RecallColors.line.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: _isPlaying
                          ? 'Pause pronunciation'
                          : 'Play pronunciation',
                      onPressed: _loading ? null : _togglePlayback,
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                    ),
                    Expanded(
                      child: Slider(
                        value: totalMilliseconds == 0
                            ? 0
                            : positionMilliseconds,
                        max: totalMilliseconds == 0 ? 1 : totalMilliseconds,
                        onChanged: _sourceReady && totalMilliseconds > 0
                            ? (milliseconds) {
                                setState(() {
                                  _draggingSlider = true;
                                  _position = Duration(
                                    milliseconds: milliseconds.round(),
                                  );
                                });
                              }
                            : null,
                        onChangeEnd: _sourceReady && totalMilliseconds > 0
                            ? _seek
                            : null,
                      ),
                    ),
                    Text(
                      '${formatAudioDuration(_position)} / '
                      '${formatAudioDuration(_duration)}',
                      style: const TextStyle(
                        color: RecallColors.faint,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final rate in _rates)
                        ChoiceChip(
                          label: Text(formatPlaybackRate(rate)),
                          selected: _rate == rate,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => _changeRate(rate),
                        ),
                    ],
                  ),
                ),
                if (_error case final error?) ...[
                  const SizedBox(height: 4),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gives Darwin's extensionless temporary file enough type information for
/// AVPlayer to recognize the downloaded bytes as MP3 audio.
BytesSource languageAudioSource(Uint8List bytes) =>
    BytesSource(bytes, mimeType: 'audio/mpeg');

String formatAudioDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String formatPlaybackRate(double rate) => '${rate.toStringAsFixed(2)}×'
    .replaceFirst('.00', '')
    .replaceFirst(RegExp(r'0(?=×$)'), '');
