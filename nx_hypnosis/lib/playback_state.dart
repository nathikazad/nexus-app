import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'desires.dart';
import 'listening.dart';
import 'remote_collection.dart';

class PlaybackCheckpoint {
  const PlaybackCheckpoint({
    required this.tapeId,
    required this.audioRevision,
    required this.positionMs,
    required this.repeat,
    required this.speed,
    required this.updatedAtMs,
  });
  final String? tapeId;
  final String? audioRevision;
  final int positionMs;
  final bool repeat;
  final double speed;
  final int updatedAtMs;

  Map<String, dynamic> toJson() => {
    'tape_id': tapeId,
    'audio_revision': audioRevision,
    'position_ms': positionMs,
    'repeat': repeat,
    'speed': speed,
    'updated_at_ms': updatedAtMs,
  };

  static PlaybackCheckpoint? parse(dynamic value) {
    if (value is! Map) return null;
    final position = value['position_ms'];
    final speed = value['speed'];
    final updated = value['updated_at_ms'];
    if (position is! int ||
        position < 0 ||
        position > 604800000 ||
        speed is! num ||
        !speed.isFinite ||
        speed < 0.25 ||
        speed > 3 ||
        updated is! int ||
        updated <= 0 ||
        value['repeat'] is! bool ||
        (value['tape_id'] != null && value['tape_id'] is! String) ||
        (value['audio_revision'] != null &&
            value['audio_revision'] is! String)) {
      return null;
    }
    return PlaybackCheckpoint(
      tapeId: value['tape_id'],
      audioRevision: value['audio_revision'],
      positionMs: position,
      repeat: value['repeat'],
      speed: speed.toDouble(),
      updatedAtMs: updated,
    );
  }
}

/// A local checkpoint is durable before it is sent. Server timestamps arbitrate
/// delayed writes; an in-flight response cannot replace a newer local action.
class PlaybackState extends WidgetsBindingObserver {
  PlaybackState({
    required this.listening,
    required this.tapes,
    required this.readLocal,
    required this.writeLocal,
    required this.exchange,
  });

  factory PlaybackState.forCollection(
    Listening listening,
    RemoteCollection data,
  ) {
    final key = 'nx_hypnosis.playback.v1:${data.user.storageKey}';
    return PlaybackState(
      listening: listening,
      tapes: () => data.tapes,
      readLocal: () async =>
          (await SharedPreferences.getInstance()).getString(key),
      writeLocal: (body) async {
        if (!await (await SharedPreferences.getInstance()).setString(
          key,
          body,
        )) {
          throw StateError('Could not save playback');
        }
      },
      exchange: (checkpoint) async {
        final uri = data.endpoint('/hypnosis/state');
        final response =
            await (checkpoint == null
                    ? data.client.get(uri)
                    : data.client.put(
                        uri,
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode(checkpoint.toJson()),
                      ))
                .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw StateError('Playback sync unavailable');
        }
        return PlaybackCheckpoint.parse(jsonDecode(response.body)['playback']);
      },
    );
  }

  final Listening listening;
  final List<Tape> Function() tapes;
  final Future<String?> Function() readLocal;
  final Future<void> Function(String) writeLocal;
  final Future<PlaybackCheckpoint?> Function(PlaybackCheckpoint?) exchange;
  PlaybackCheckpoint? current;
  Timer? _timer;
  bool _disposed = false;
  bool _applying = false;
  bool _syncing = false;
  bool _dirty = false;
  bool _ready = false;
  bool _unresolved = false;
  int _activity = 0;
  String? _controls;
  Future<void> _writes = Future.value();

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    listening.addListener(_changed);
    final activity = _activity;
    try {
      final raw = await readLocal();
      if (!_disposed &&
          !listening.opening &&
          !listening.loading &&
          activity == _activity &&
          raw != null) {
        current = PlaybackCheckpoint.parse(jsonDecode(raw));
        _apply(current);
        // Re-sending an acknowledged checkpoint is idempotent and also repairs
        // a process exit between the local write and the HTTP request.
        _dirty = current != null;
      }
    } catch (_) {
      /* Missing/corrupt storage is repaired by the next checkpoint. */
    }
    if (_disposed) return;
    _ready = true;
    if (_activity != activity) capture();
    _controls = _controlKey();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      capture();
      unawaited(sync());
    });
    await sync();
  }

  String _controlKey() => jsonEncode([
    listening.tape?.id,
    listening.tape?.audioRevision,
    listening.repeatEnabled,
    listening.speed,
    listening.playing,
    listening.checkpointRevision,
  ]);

  void _changed() {
    if (_disposed || _applying) return;
    // Loading is transient; never save its temporary zero position.
    if (listening.opening || listening.loading || listening.error != null) {
      return;
    }
    final controls = _controlKey();
    if (_controls == controls) return;
    _controls = controls;
    _activity++;
    _unresolved = false;
    if (_ready) {
      capture();
      unawaited(sync());
    }
  }

  void capture() {
    if (_disposed ||
        !_ready ||
        _applying ||
        _unresolved ||
        listening.opening ||
        listening.loading ||
        listening.error != null) {
      return;
    }
    final next = PlaybackCheckpoint(
      tapeId: listening.tape?.id,
      audioRevision: listening.tape?.audioRevision,
      positionMs: listening.tape == null
          ? 0
          : listening.position.inMilliseconds,
      repeat: listening.repeatEnabled,
      speed: listening.speed,
      updatedAtMs: max(
        DateTime.now().millisecondsSinceEpoch,
        (current?.updatedAtMs ?? 0) + 1,
      ),
    );
    final old = current;
    if (old == null && next.tapeId == null) return;
    if (old != null &&
        old.tapeId == next.tapeId &&
        old.audioRevision == next.audioRevision &&
        old.positionMs == next.positionMs &&
        old.repeat == next.repeat &&
        old.speed == next.speed) {
      return;
    }
    current = next;
    _dirty = true;
    _save(next);
  }

  void _save(PlaybackCheckpoint value) {
    _writes = _writes
        .catchError((Object _) {})
        .then((_) => writeLocal(jsonEncode(value.toJson())));
    // Keep failures retryable without an unhandled asynchronous error.
    unawaited(_writes.catchError((Object _) {}));
  }

  void _apply(PlaybackCheckpoint? value) {
    if (value == null || _disposed) return;
    final tape = tapes().where((t) => t.id == value.tapeId).firstOrNull;
    // Do not discard a checkpoint while the library is still refreshing.
    _unresolved =
        value.tapeId != null && (tape == null || tape.audioAsset == null);
    if (_unresolved) return;
    _applying = true;
    listening.restore(
      tape,
      position: Duration(
        milliseconds: tape?.audioRevision == value.audioRevision
            ? value.positionMs
            : 0,
      ),
      speed: value.speed,
      repeat: value.repeat,
    );
    _controls = _controlKey();
    _applying = false;
  }

  Future<void> sync() async {
    if (_disposed || !_ready || _syncing) return;
    _syncing = true;
    final sent = current;
    try {
      await _writes;
      final remote = await exchange(_dirty ? sent : null);
      if (_disposed || !identical(sent, current)) return;
      if (remote != null &&
          (current == null || remote.updatedAtMs > current!.updatedAtMs)) {
        if (listening.playing || listening.opening || listening.loading) return;
        current = remote;
        _save(remote);
        _apply(remote);
      }
      _dirty = false;
    } catch (_) {
      // Offline/server failure: retain the local checkpoint and retry next tick.
      if (current != null) _save(current!);
    } finally {
      _syncing = false;
    }
  }

  void libraryChanged() {
    if (!listening.playing && listening.tape == null) _apply(current);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    capture();
    unawaited(sync());
  }

  void dispose() {
    capture();
    _disposed = true;
    _timer?.cancel();
    listening.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
  }
}
