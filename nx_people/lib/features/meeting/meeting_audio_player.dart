import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_voice/nx_voice.dart';
import 'package:path_provider/path_provider.dart';

class MeetingAudioPlayer extends ConsumerStatefulWidget {
  const MeetingAudioPlayer({
    super.key,
    required this.deviceId,
    required this.fileId,
  });
  final String deviceId, fileId;
  @override
  ConsumerState<MeetingAudioPlayer> createState() => _MeetingAudioPlayerState();
}

class _MeetingAudioPlayerState extends ConsumerState<MeetingAudioPlayer> {
  final player = AudioPlayer();
  final subscriptions = <StreamSubscription>[];
  Directory? directory;
  bool busy = false, ready = false;
  String? error;
  Duration position = Duration.zero, duration = Duration.zero;
  PlayerState state = PlayerState.stopped;
  double volume = 1;
  @override
  void initState() {
    super.initState();
    subscriptions.addAll([
      player.onPositionChanged.listen((v) {
        if (mounted) setState(() => position = v);
      }),
      player.onDurationChanged.listen((v) {
        if (mounted) setState(() => duration = v);
      }),
      player.onPlayerStateChanged.listen((v) {
        if (mounted) setState(() => state = v);
      }),
    ]);
  }

  Future<void> play() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!ready) {
        final client = ref.read(nexusHttpClientProvider);
        final base = ref.read(imageBaseUrlProvider);
        if (client == null || base == null) {
          throw StateError('No active account');
        }
        final response = await client
            .send(
              http.Request(
                'GET',
                Uri.parse('$base/audio/file').replace(
                  queryParameters: {
                    'device_id': widget.deviceId,
                    'name': '${widget.fileId}.opusraw',
                  },
                ),
              ),
            )
            .timeout(const Duration(seconds: 60));
        if (response.statusCode != 200) {
          await response.stream.drain<void>();
          throw StateError('Download failed (${response.statusCode})');
        }
        if (!mounted) {
          await response.stream.drain<void>();
          return;
        }
        final dir = directory ??= await (await getTemporaryDirectory())
            .createTemp('people-meeting-');
        final opus = File('${dir.path}/audio.opusraw');
        final wav = File('${dir.path}/audio.wav');
        await response.stream.pipe(opus.openWrite());
        await decodeNecklaceRecording(opus, wav);
        if (!mounted) {
          await dir.delete(recursive: true);
          return;
        }
        await player.setSource(DeviceFileSource(wav.path));
        ready = true;
      }
      if (!mounted) return;
      if (state == PlayerState.playing) {
        await player.pause();
      } else {
        if (state == PlayerState.completed) await player.seek(Duration.zero);
        await player.resume();
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not play recording. Tap to retry.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      } else {
        final dir = directory;
        if (dir != null && await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    }
  }

  @override
  void dispose() {
    for (final s in subscriptions) {
      s.cancel();
    }
    final dir = directory;
    // Let any in-progress decode finish before deleting its files.
    unawaited(
      player.dispose().then((_) async {
        if (!busy && dir != null && await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }),
    );
    super.dispose();
  }

  String clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: EdgeInsets.zero,
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: .5),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.graphic_eq_rounded, size: 18),
              SizedBox(width: 8),
              Text('Recording', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.filled(
                tooltip: state == PlayerState.playing
                    ? 'Pause recording'
                    : 'Play recording',
                onPressed: busy ? null : play,
                icon: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(),
                      )
                    : Icon(
                        state == PlayerState.playing
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
              ),
              Expanded(
                child: Slider(
                  value: position.inMilliseconds.toDouble().clamp(
                    0,
                    duration.inMilliseconds.toDouble(),
                  ),
                  max: duration.inMilliseconds > 0
                      ? duration.inMilliseconds.toDouble()
                      : 1,
                  onChanged: ready && duration > Duration.zero
                      ? (v) => player.seek(Duration(milliseconds: v.round()))
                      : null,
                ),
              ),
              Text('${clock(position)} / ${clock(duration)}'),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.volume_up_outlined, size: 18),
              Expanded(
                child: Slider(
                  value: volume,
                  onChanged: (v) {
                    setState(() => volume = v);
                    player.setVolume(v);
                  },
                ),
              ),
            ],
          ),
          if (error != null) Text(error!),
        ],
      ),
    ),
  );
}
