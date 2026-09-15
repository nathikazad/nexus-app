import 'playback_timeline.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:nx_offline/nx_offline.dart';
import 'offline_cache.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nx_auth/nx_auth.dart';
import 'desires.dart';

class RemoteCollection extends HypnosisCollection {
  RemoteCollection(
    this.user, {
    NexusAuthenticatedClient? transport,
    this.cache,
    this.stateSession,
  }) : client =
           transport ??
           NexusAuthenticatedClient(preset: user.preset, userId: user.userId),
       super([], [], '') {
    synchronizer = SyncSupervisor<String>(
      reconciler: _CollectionPull(_pull),
      retryDelay: const Duration(seconds: 5),
    );
    _statusSubscription = synchronizer.statusChanges.listen((_) => _changed());
  }
  final User user;
  final HypnosisCache? cache;
  final AppSyncSession? Function()? stateSession;
  String? _appliedRoot;
  late final SyncSupervisor<String> synchronizer;
  StreamSubscription<SyncStatus>? _statusSubscription;
  final savedRecordings = <String>{};
  final Map<String, Future<String>> _audioRequests = {};
  Future<void>? _prefetch;
  final _files = AttachmentQueue();
  Future<void>? _availability;
  Future<void>? _closing;
  Future<void> _operations = Future.value();
  bool _disposed = false;
  bool downloading = false;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<T> _serialize<T>(Future<T> Function() work) {
    final result = _operations.then((_) => work());
    _operations = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<void> initialize() async {
    String? saved;
    try {
      saved = await cache?.readCollection();
    } on Exception {
      /* Refresh repairs a missing body. */
    }
    if (saved != null) {
      try {
        _accept(200, saved);
        unawaited(_availability = _checkSavedRecordings());
        return;
      } catch (_) {
        /* Repair an invalid snapshot. */
      }
    }
    await refresh();
  }

  Future<void> refresh({SyncReason reason = SyncReason.manual}) =>
      synchronizer.requestFull(reason);

  Future<void> _persist(int status, String body) async {
    // Validate the entire response before replacing either the cache or the UI.
    final parsed = _decode(status, body);
    await cache?.saveCollection(jsonEncode(jsonDecode(body)));
    _replace(parsed.$1, parsed.$2);
  }

  final NexusAuthenticatedClient client;
  Uri endpoint(String path) =>
      Uri.parse('${resolve(user.preset).imageHttp}$path');

  Future<void> _pull() async {
    await _serialize(() async {
      final session = stateSession?.call();
      final remote = await session?.manifest();
      if (session != null && remote != null) {
        // The collection is a single compatibility projection; asset downloads
        // remain independent and are retried even when its metadata is equal.
        if (_appliedRoot != remote.root) {
          final items = await session.download(remote, {0});
          if (items.length != 1)
            throw StateError('Missing Hypnosis collection');
          await _persist(200, jsonEncode(items.single['payload']));
          _appliedRoot = remote.root;
        }
        return;
      }
      final response = await client
          .get(endpoint('/apps/hypnosis/initial'))
          .timeout(const Duration(seconds: 30));
      await _persist(response.statusCode, response.body);
    });
    unawaited(prefetchRecordings());
  }

  void _accept(int status, String body) {
    final parsed = _decode(status, body);
    _replace(parsed.$1, parsed.$2);
  }

  (List<Desire>, List<Tape>) _decode(int status, String body) {
    if (status != 200) {
      throw Exception(
        status == 401
            ? 'Please sign in again.'
            : 'Could not save or load your collection. Please try again.',
      );
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final nextDesires = (json['desires'] as List)
        .map(
          (d) =>
              Desire(id: d['id'], title: d['title'], belief: d['belief'] ?? ''),
        )
        .toList();
    final nextTapes = (json['tapes'] as List)
        .map(
          (t) => Tape(
            id: t['id'],
            desireId: t['desire_id'],
            title: t['title'],
            story: t['story'] ?? '',
            prompt: t['prompt'] ?? '',
            audioAsset: (t['audio'] as Map?)?['link'] as String?,
            audioRevision: jsonEncode(t['audio']),
            timeline: PlaybackTimeline.fromAudio(t['audio']),
          ),
        )
        .toList();
    final ids = nextDesires.map((d) => d.id).toSet();
    if (ids.length != nextDesires.length ||
        nextTapes.map((t) => t.id).toSet().length != nextTapes.length ||
        nextTapes.any((t) => !ids.contains(t.desireId))) {
      throw const FormatException('Invalid collection relationships');
    }
    return (nextDesires, nextTapes);
  }

  void _replace(List<Desire> nextDesires, List<Tape> nextTapes) {
    desires
      ..clear()
      ..addAll(nextDesires);
    savedRecordings.removeWhere(
      (id) => !nextTapes.any(
        (next) =>
            next.id == id &&
            tapes.any(
              (old) => old.id == id && old.audioRevision == next.audioRevision,
            ),
      ),
    );
    tapes
      ..clear()
      ..addAll(nextTapes);
    _changed();
  }

  Future<void> write(String kind, Map<String, dynamic> body) =>
      _serialize(() async {
        final response = await client
            .post(
              endpoint('/hypnosis/$kind'),
              headers: {'content-type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 30));
        await _persist(response.statusCode, response.body);
      });

  @override
  Future<Desire> saveDesire(String title, String belief, {String? id}) async {
    final previous = desires.map((d) => d.id).toSet();
    await write('desires', {'title': title, 'belief': belief, 'id': ?id});
    return id == null
        ? desires.firstWhere((d) => !previous.contains(d.id))
        : desire(id);
  }

  @override
  Future<Tape> createTape(String desireId, String title, String prompt) async {
    final previous = tapes.map((t) => t.id).toSet();
    await write('tapes', {
      'title': title,
      'desire_id': desireId,
      'prompt': prompt,
      'story': '',
    });
    return tapes.firstWhere((t) => !previous.contains(t.id));
  }

  @override
  Future<void> removeDesire(Desire item, {String? moveTo}) =>
      _serialize(() async {
        final response = await client
            .delete(
              endpoint('/hypnosis/desires'),
              headers: {'content-type': 'application/json'},
              body: jsonEncode({'id': item.id, 'move_to': ?moveTo}),
            )
            .timeout(const Duration(seconds: 30));
        await _persist(response.statusCode, response.body);
      });

  Future<Uint8List> recording(Tape tape) async {
    final response = await client
        .get(endpoint(tape.audioAsset!))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) throw Exception('Could not load recording');
    return response.bodyBytes;
  }

  bool _currentRecording(Tape tape) => tapes.any(
    (current) =>
        current.id == tape.id &&
        current.audioRevision == tape.audioRevision &&
        current.audioAsset == tape.audioAsset,
  );

  Future<String> recordingPath(Tape tape) {
    final key = '${tape.id}:${tape.audioRevision}:${tape.audioAsset}';
    return _audioRequests[key] ??= _recordingPath(tape).whenComplete(() {
      _audioRequests.remove(key);
    });
  }

  Future<String> _recordingPath(Tape tape) async {
    final storage = cache!;
    final saved = await storage.recordingPath(tape);
    if (saved != null) {
      if (_currentRecording(tape)) savedRecordings.add(tape.id);
      _changed();
      return saved;
    }
    if (_disposed) throw StateError('Collection closed');
    final response = await client
        .send(http.Request('GET', endpoint(tape.audioAsset!)))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw Exception('Could not download recording');
    }
    final path = await storage.saveRecording(
      tape,
      response.stream.timeout(const Duration(seconds: 60)),
    );
    if (_currentRecording(tape)) savedRecordings.add(tape.id);
    _changed();
    return path;
  }

  Future<void> _checkSavedRecordings() async {
    if (cache == null) return;
    for (final tape in tapes.toList()) {
      if (_disposed) return;
      if (tape.audioAsset != null && await cache!.recordingPath(tape) != null) {
        if (_currentRecording(tape)) savedRecordings.add(tape.id);
      }
    }
    _changed();
  }

  Future<void> prefetchRecordings() =>
      _prefetch ??= _prefetchRecordings().whenComplete(() => _prefetch = null);
  Future<void> _prefetchRecordings() async {
    if (cache == null || _disposed) return;
    downloading = true;
    _changed();
    try {
      final items = tapes.where((t) => t.audioAsset != null).toList();
      await Future.wait(
        items.map((tape) async {
          try {
            await _files.run(tape.id, () => recordingPath(tape));
          } catch (_) {
            // Retry on next sync or play.
          }
        }),
      );
    } finally {
      downloading = false;
      _changed();
    }
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _disposed = true;
    client.close();
    await _statusSubscription?.cancel();
    await synchronizer.close();
    await _operations;
    await _availability;
    await _files.close();
    await _prefetch;
    await Future.wait(
      _audioRequests.values.map((future) async {
        try {
          await future;
        } catch (_) {}
      }),
    );
    await cache?.close();
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}

final class _CollectionPull implements PullReconciler<String> {
  const _CollectionPull(this.pull);
  final Future<void> Function() pull;
  @override
  Future<void> pullAll() => pull();
  @override
  Future<void> pullKeys(Set<String> keys) => pull();
}
