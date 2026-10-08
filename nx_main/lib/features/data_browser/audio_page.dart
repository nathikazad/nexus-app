import 'dart:io';
import 'dart:async';
import 'package:nx_voice/nx_voice.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:audioplayers/audioplayers.dart';

class NecklaceAudioPage extends ConsumerStatefulWidget {
  const NecklaceAudioPage({super.key});
  @override
  ConsumerState<NecklaceAudioPage> createState() => _NecklaceAudioPageState();
}

class _NecklaceAudioPageState extends ConsumerState<NecklaceAudioPage> {
  final _player = AudioPlayer();
  final List<Map<String, dynamic>> _rows = [];
  final Map<String, Duration> _knownDurations = {};
  bool _loading = false, _more = true;
  String? _error, _playing;
  Directory? _audioDir;
  bool _downloading = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Duration _position = Duration.zero, _duration = Duration.zero;
  PlayerState _playbackState = PlayerState.stopped;
  double _volume = 1;
  bool _adjustingVolume = false;
  File? _originalWav;
  double? _seekPreview;
  String _title = 'Recording';
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(reset: true));
    _subscriptions.addAll([
      _player.onDurationChanged.listen((value) {
        if (mounted) setState(() => _duration = value);
      }),
      _player.onPositionChanged.listen((value) {
        if (mounted) setState(() => _position = value);
      }),
      _player.onPlayerStateChanged.listen((value) {
        if (mounted) setState(() => _playbackState = value);
      }),
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _position = _duration);
      }),
    ]);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    _audioDir?.delete(recursive: true).catchError((_) => Directory(''));
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _rows.clear();
    });
    try {
      final client = ref.read(nexusHttpClientProvider);
      final base = ref.read(imageBaseUrlProvider);
      if (client == null || base == null)
        throw StateError('Select a server and domain');
      final response = await client
          .get(Uri.parse('$base/audio/recordings?offset=${_rows.length}'));
      if (response.statusCode != 200)
        throw StateError('Could not load recordings (${response.statusCode})');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _rows.addAll((data['recordings'] as List)
            .map((e) => Map<String, dynamic>.from(e)));
        _more = data['more'] == true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _play(Map<String, dynamic> row) async {
    if (_downloading || _adjustingVolume) return;
    final key = '${row['device_id']}/${row['name']}';
    try {
      if (_playing == key) {
        await _togglePlayback();
        return;
      }
      await _player.stop();
      final base = ref.read(imageBaseUrlProvider);
      final client = ref.read(nexusHttpClientProvider);
      if (client == null) throw StateError('Select a domain');
      final url = Uri.parse('$base/audio/file').replace(queryParameters: {
        'device_id': row['device_id'] as String,
        'name': row['name'] as String
      });
      setState(() {
        _downloading = true;
        _playing = null;
        _position = _duration = Duration.zero;
        _seekPreview = null;
        _error = 'Preparing playback…';
      });
      final dir = _audioDir ??=
          await (await getTemporaryDirectory()).createTemp('necklace-audio-');
      final file = File('${dir.path}/playback.wav');
      final opus = File('${dir.path}/recording.opusraw');
      final response = await client.send(http.Request('GET', url));
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        throw StateError('Audio download failed (${response.statusCode})');
      }
      await response.stream.pipe(opus.openWrite());
      await decodeNecklaceRecording(opus, file);
      if (!mounted) {
        await dir.delete(recursive: true);
        return;
      }
      // The locally decoded file is PCM16 mono at 16 kHz (32,000 bytes/sec).
      final duration = Duration(
          microseconds: ((await file.length() - 44) * 1000000 ~/ 32000));
      _knownDurations[key] = duration;
      _duration = duration;
      await _player.setReleaseMode(ReleaseMode.stop);
      _originalWav = file;
      final playback = await _volumeSource(_volume);
      await _player.play(DeviceFileSource(playback.path),
          volume: _volume.clamp(0.0, 1.0));
      if (mounted)
        setState(() {
          _playing = key;
          _title = DateTime.parse(row['time'] as String)
              .toLocal()
              .toString()
              .split('.')
              .first;
          _error = null;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _playing = null;
          _error = 'Playback failed: $e';
        });
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<File> _volumeSource(double volume) async {
    final original = _originalWav!;
    if (volume <= 1) return original;
    final input = await original.open();
    final file = File('${original.parent.path}/boosted.wav');
    final output = await file.open(mode: FileMode.write);
    try {
      await output.writeFrom(await input.read(44));
      while (true) {
        final pcm = await input.read(65536);
        if (pcm.isEmpty) break;
        await output.writeFrom(amplifyPcm16(pcm, volume));
      }
    } finally {
      await input.close();
      await output.close();
    }
    return file;
  }

  Future<void> _applyVolume(double value) async {
    if (_adjustingVolume || _originalWav == null) return;
    setState(() => _adjustingVolume = true);
    await _control(() async {
      final position = _position;
      final wasPlaying = _playbackState == PlayerState.playing;
      await _player.pause();
      final source = await _volumeSource(value);
      if (!mounted) return;
      await _player.setSource(DeviceFileSource(source.path));
      await _player.setVolume(value.clamp(0.0, 1.0));
      await _player.seek(position);
      if (wasPlaying) await _player.resume();
    });
    if (mounted) setState(() => _adjustingVolume = false);
  }

  Future<void> _control(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = 'Playback control failed: $e');
    }
  }

  Future<void> _togglePlayback() => _control(() async {
        if (_playbackState == PlayerState.playing) {
          await _player.pause();
        } else {
          if (_playbackState == PlayerState.completed ||
              (_duration > Duration.zero && _position >= _duration)) {
            await _player.seek(Duration.zero);
          }
          await _player.resume();
        }
      });

  Future<void> _seek(double milliseconds) => _control(() async {
        final value = milliseconds.clamp(0, _duration.inMilliseconds).round();
        await _player.seek(Duration(milliseconds: value));
        if (mounted) setState(() => _position = Duration(milliseconds: value));
      });

  String _time(Duration value) {
    final seconds = value.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Widget _controls() {
    final max = _duration.inMilliseconds.toDouble();
    final position = (_seekPreview ?? _position.inMilliseconds.toDouble())
        .clamp(0.0, max > 0 ? max : 1.0);
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Row(children: [
                Text(_time(Duration(milliseconds: position.round()))),
                Expanded(
                    child: Slider(
                  semanticFormatterCallback: (value) =>
                      _time(Duration(milliseconds: value.round())),
                  value: position,
                  max: max > 0 ? max : 1,
                  onChanged: max > 0
                      ? (value) => setState(() => _seekPreview = value)
                      : null,
                  onChangeEnd: (value) async {
                    await _seek(value);
                    if (mounted) setState(() => _seekPreview = null);
                  },
                )),
                Text(_time(_duration)),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                TextButton(
                    onPressed: () => _seek(_position.inMilliseconds - 10000.0),
                    child: const Text('−10 sec')),
                IconButton(
                  tooltip:
                      _playbackState == PlayerState.playing ? 'Pause' : 'Play',
                  icon: Icon(_playbackState == PlayerState.playing
                      ? Icons.pause
                      : Icons.play_arrow),
                  onPressed: _togglePlayback,
                ),
                TextButton(
                    onPressed: () => _seek(_position.inMilliseconds + 10000.0),
                    child: const Text('+10 sec')),
              ]),
              Row(children: [
                const Text('Volume'),
                Expanded(
                    child: Slider(
                  value: _volume,
                  max: 1.5,
                  label: '${(_volume * 100).round()}%',
                  semanticFormatterCallback: (value) =>
                      '${(value * 100).round()} percent volume',
                  onChanged: _adjustingVolume
                      ? null
                      : (value) {
                          setState(() => _volume = value);
                        },
                  onChangeEnd: _applyVolume,
                )),
                Text('${(_volume * 100).round()}%'),
              ]),
            ]),
          )),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Necklace audio'), actions: [
        IconButton(
            onPressed: _loading ? null : () => _load(reset: true),
            icon: const Icon(Icons.refresh))
      ]),
      bottomNavigationBar: _playing != null ? _controls() : null,
      body: ListView(children: [
        const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                'Saved background recordings. New recordings appear after upload completes.')),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
        if (!_loading && _rows.isEmpty && _error == null)
          const ListTile(title: Text('No recordings yet')),
        for (final row in _rows)
          ListTile(
              leading: Icon(_playing == '${row['device_id']}/${row['name']}' &&
                      _playbackState == PlayerState.playing
                  ? Icons.pause
                  : Icons.play_arrow),
              title: Text(DateTime.parse(row['time'] as String)
                  .toLocal()
                  .toString()
                  .split('.')
                  .first),
              subtitle: Text('${row['name']} · ${row['size']} bytes'),
              trailing: _knownDurations
                      .containsKey('${row['device_id']}/${row['name']}')
                  ? Text(_time(
                      _knownDurations['${row['device_id']}/${row['name']}']!))
                  : null,
              onTap: () => _play(row)),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_more && !_loading && _rows.isNotEmpty)
          TextButton(onPressed: _load, child: const Text('Load more')),
      ]));
}
