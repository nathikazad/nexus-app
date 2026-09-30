import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/browser/browser.dart';

final sharedPronunciationPlayerProvider = Provider<SharedPronunciationPlayer>((
  ref,
) {
  // Changing account/audio repository also stops the previous account's audio.
  ref.watch(cardAudioRepositoryProvider);
  AudioPlayer? player;
  StreamSubscription<void>? completion;
  late final SharedPronunciationPlayer shared;
  shared = SharedPronunciationPlayer(
    stop: () async {
      await player?.stop();
    },
    play: (bytes) async {
      if (player == null) {
        player = AudioPlayer();
        completion = player!.onPlayerComplete.listen((_) => shared.completed());
      }
      await player!.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
    },
    close: () async {
      await completion?.cancel();
      await player?.dispose();
    },
  );
  ref.onDispose(shared.dispose);
  return shared;
});

/// One output, with latest-request-wins fetching and serialized native commands.
class SharedPronunciationPlayer extends ChangeNotifier {
  SharedPronunciationPlayer({
    required this.stop,
    required this.play,
    required this.close,
  });
  final Future<void> Function() stop;
  final Future<void> Function(Uint8List) play;
  final Future<void> Function() close;
  Object? owner;
  bool loading = false;
  bool playing = false;
  bool _closed = false;
  int _request = 0;
  Future<void> _commands = Future.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _commands.then((_) => action());
    _commands = next.catchError((Object _) {});
    return next;
  }

  Future<void> start(
    Object sender,
    String url,
    CardAudioRepository repository,
  ) async {
    if (_closed) return;
    final request = ++_request;
    owner = sender;
    loading = true;
    playing = false;
    notifyListeners();
    try {
      await _enqueue(stop);
      if (_closed || request != _request) return;
      final bytes = await repository.fetch(url);
      await _enqueue(() async {
        if (_closed || request != _request) return;
        await play(bytes);
        if (_closed || request != _request) return;
        loading = false;
        playing = true;
        notifyListeners();
      });
    } catch (error) {
      if (!_closed && request == _request) {
        loading = false;
        playing = false;
        notifyListeners();
      }
      rethrow;
    }
  }

  void completed() {
    if (_closed || !playing) return;
    playing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _request++;
    unawaited(_enqueue(close));
    super.dispose();
  }
}
