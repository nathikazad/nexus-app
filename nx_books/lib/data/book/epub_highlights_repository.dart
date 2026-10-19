import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:shared_preferences/shared_preferences.dart';

String newHighlightId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Per-ID last-write-wins records, including tombstones. Mirrors the DB merge.
Map<String, dynamic> mergeEpubHighlights(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final result = Map<String, dynamic>.from(a);
  for (final entry in b.entries) {
    if (entry.value is! Map) continue;
    final old = result[entry.key];
    final next = entry.value as Map;
    final time = (next['updated_at'] as num? ?? 0).compareTo(
      old is Map ? old['updated_at'] as num? ?? 0 : 0,
    );
    if (old is! Map ||
        time > 0 ||
        (time == 0 &&
            (next['revision']?.toString() ?? '').compareTo(
                  old['revision']?.toString() ?? '',
                ) >
                0)) {
      result[entry.key] = entry.value;
    }
  }
  return result;
}

abstract interface class EpubHighlightsRemote {
  Future<Map<String, dynamic>> load(int bookId);
  Future<void> save(int bookId, Map<String, dynamic> records);
}

class KgqlEpubHighlightsRemote implements EpubHighlightsRemote {
  KgqlEpubHighlightsRemote(this.client);
  final GraphQLClient client;
  Future<Map<String, dynamic>> _file(int id) async {
    final model = await fetchKgqlModelById(
      client,
      modelTypeName: 'Book',
      id: id,
      struct: const {'id': true, 'book_file': true},
    );
    final file = model?.attributes?['book_file'];
    if (file is! Map) throw StateError('Book has no attached file');
    return Map<String, dynamic>.from(file);
  }

  @override
  Future<Map<String, dynamic>> load(int bookId) async {
    final value = (await _file(bookId))['highlights'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  @override
  Future<void> save(int bookId, Map<String, dynamic> records) async {
    final file = await _file(bookId);
    // The database merges per-ID records under the attribute row lock, including
    // writes from older clients that do not know about highlights.
    await setKgqlModel(
      client,
      SetModelRequest(
        id: bookId,
        attributes: [
          SetModelAttribute(
            key: 'book_file',
            value: {...file, 'highlights': records},
          ),
        ],
      ),
      auditSourceKind: 'nx_books_epub_highlights',
    );
  }
}

/// Durable session-partitioned outbox. Edits are saved locally before syncing.
class EpubHighlightsRepository {
  EpubHighlightsRepository({
    required this.account,
    required this.remote,
    this.persistData = true,
  });
  final String account;
  final EpubHighlightsRemote remote;
  final bool persistData;
  final _memory = <int, Map<String, dynamic>>{};
  final _changes = StreamController<int>.broadcast();
  Stream<int> get changes => _changes.stream;
  Future<void> _writes = Future.value();
  Future<void>? _flushing;
  Timer? _timer;
  bool _closed = false;
  String get _prefix => 'nx_books.$account.epub_highlights.';
  Map<String, dynamic> _decode(String? raw) =>
      raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw));
  Future<Map<String, dynamic>> _entry(int id) async => persistData
      ? _decode(
          (await SharedPreferences.getInstance()).getString('$_prefix$id'),
        )
      : _memory[id] ?? {};
  Future<void> _put(int id, Map<String, dynamic> entry) async {
    if (persistData) {
      if (!await (await SharedPreferences.getInstance()).setString(
        '$_prefix$id',
        jsonEncode(entry),
      )) {
        throw StateError('Could not save highlights on this device');
      }
    } else {
      _memory[id] = entry;
    }
    if (!_closed) _changes.add(id);
  }

  Map<String, dynamic> _records(Map<String, dynamic> entry) =>
      Map<String, dynamic>.from(entry['records'] as Map? ?? {});
  Future<T> _serialize<T>(Future<T> Function() action) {
    final work = _writes.then((_) => action());
    _writes = work.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return work;
  }

  Future<Map<String, dynamic>> load(int id, {bool refreshRemote = true}) async {
    if (refreshRemote && !_closed) {
      try {
        final incoming = await remote
            .load(id)
            .timeout(const Duration(seconds: 10));
        if (_closed) return {};
        await _serialize(() async {
          final entry = await _entry(id);
          await _put(id, {
            ...entry,
            'records': mergeEpubHighlights(_records(entry), incoming),
          });
        });
      } catch (_) {
        /* Offline: keep both cached records and pending edits. */
      }
    }
    await _writes;
    return _records(await _entry(id));
  }

  Future<void> acceptRemote(int id, Map<String, dynamic> incoming) =>
      _serialize(() async {
        final entry = await _entry(id);
        await _put(id, {
          ...entry,
          'records': mergeEpubHighlights(_records(entry), incoming),
        });
      });

  Future<void> save(int id, Map<String, dynamic> record) {
    if (_closed) return Future.error(StateError('Highlight session closed'));
    final snapshot = Map<String, dynamic>.from(record);
    return _serialize(() async {
      final entry = await _entry(id);
      await _put(id, {
        'records': mergeEpubHighlights(_records(entry), {
          snapshot['id'] as String: snapshot,
        }),
        'pending': true,
      });
      _schedule(const Duration(seconds: 1));
    });
  }

  void _schedule(Duration delay) {
    if (_closed || _timer != null) return;
    _timer = Timer(delay, () {
      _timer = null;
      unawaited(flush().catchError((Object _) {}));
    });
  }

  Future<void> flush() =>
      _flushing ??= _flush().whenComplete(() => _flushing = null);
  Future<void> _flush() async {
    await _writes;
    final ids = persistData
        ? (await SharedPreferences.getInstance())
              .getKeys()
              .where((k) => k.startsWith(_prefix))
              .map((k) => int.parse(k.substring(_prefix.length)))
              .toList()
        : _memory.keys.toList();
    var retry = false;
    for (final id in ids) {
      if (_closed) return;
      final entry = await _entry(id);
      if (entry['pending'] != true) continue;
      final before = jsonEncode(entry);
      try {
        await remote
            .save(id, _records(entry))
            .timeout(const Duration(seconds: 15));
        if (_closed) return;
        final incoming = await remote
            .load(id)
            .timeout(const Duration(seconds: 15));
        if (_closed) return;
        await _serialize(() async {
          final current = await _entry(id);
          final pending = jsonEncode(current) != before;
          retry |= pending;
          await _put(id, {
            'records': mergeEpubHighlights(_records(current), incoming),
            'pending': pending,
          });
        });
      } catch (_) {
        retry = true;
      }
    }
    if (retry) _schedule(const Duration(seconds: 15));
  }

  void dispose() {
    _closed = true;
    _timer?.cancel();
    unawaited(_changes.close());
  }
}
