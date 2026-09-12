import 'dart:async';
import 'dart:convert';

import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:shared_preferences/shared_preferences.dart';

const epubProgressAttribute = 'epub_reading_position';

abstract interface class EpubProgressRemote {
  Future<Map<String, dynamic>?> load(int bookId);
  Future<void> save(int bookId, Map<String, dynamic> value);
}

class KgqlEpubProgressRemote implements EpubProgressRemote {
  KgqlEpubProgressRemote(this.client);
  final GraphQLClient client;

  @override
  Future<Map<String, dynamic>?> load(int bookId) async {
    final model = await fetchKgqlModelById(
      client,
      modelTypeName: 'Book',
      id: bookId,
      struct: const {'id': true, epubProgressAttribute: true},
    );
    if (model == null) throw StateError('Book no longer exists');
    final value = model.attributes?[epubProgressAttribute];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  @override
  Future<void> save(int bookId, Map<String, dynamic> value) async {
    await setKgqlModel(
      client,
      SetModelRequest(
        id: bookId,
        attributes: [
          SetModelAttribute(key: epubProgressAttribute, value: value),
        ],
      ),
      auditSourceKind: 'nx_books_epub_progress',
    );
  }
}

/// Durable, account-scoped latest-value outbox. Does not involve document
/// bodies or attachment downloads; remote failures never discard local progress.
class EpubProgressRepository {
  EpubProgressRepository({required this.account, required this.remote});
  final String account;
  final EpubProgressRemote remote;
  Future<void> _writes = Future.value();
  Future<void>? _flushing;
  Timer? _timer;
  bool _closed = false;
  String get _prefix => 'nx_books.$account.epub_progress.';
  String _key(int id) => '$_prefix$id';

  Map<String, dynamic>? _decode(String? raw) {
    try {
      return raw == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _put(
    SharedPreferences prefs,
    int id,
    Map<String, dynamic> entry,
  ) async {
    if (!await prefs.setString(_key(id), jsonEncode(entry))) {
      throw StateError('Could not save EPUB progress on this device');
    }
  }

  Future<Map<String, dynamic>?> load(int id) async {
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    var entry = _decode(prefs.getString(_key(id)));
    // An unsent local position always wins over stale server data on reopen.
    if (entry?['pending'] != true) {
      try {
        final value = await remote.load(id).timeout(const Duration(seconds: 3));
        await _writes;
        entry = _decode(prefs.getString(_key(id)));
        if (entry?['pending'] != true && value != null) {
          entry = {'value': value, 'pending': false};
          await _put(prefs, id, entry);
        }
      } catch (_) {
        /* Offline: retain the last known position. */
      }
    }
    final value = entry?['value'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  Future<void> save(int id, Map<String, dynamic> value) {
    final snapshot = Map<String, dynamic>.from(value);
    final operation = _writes.then((_) async {
      await _put(await SharedPreferences.getInstance(), id, {
        'value': snapshot,
        'pending': true,
      });
      _schedule(const Duration(seconds: 2));
    });
    _writes = operation.catchError((Object _) {});
    return operation;
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
    final prefs = await SharedPreferences.getInstance();
    try {
      for (final key in prefs.getKeys().where(
        (key) => key.startsWith(_prefix),
      )) {
        if (_closed) return;
        final id = int.tryParse(key.substring(_prefix.length));
        final raw = prefs.getString(key);
        final entry = _decode(raw);
        if (id == null || entry?['pending'] != true) continue;
        final value = Map<String, dynamic>.from(entry!['value'] as Map);
        // Avoid replaying an older offline position over newer device progress.
        final latest = await remote
            .load(id)
            .timeout(const Duration(seconds: 15));
        final localTime = DateTime.tryParse(
          value['saved_at']?.toString() ?? '',
        );
        final remoteTime = DateTime.tryParse(
          latest?['saved_at']?.toString() ?? '',
        );
        final newerRemote =
            localTime != null &&
            remoteTime != null &&
            remoteTime.isAfter(localTime);
        if (!newerRemote) {
          await remote.save(id, value).timeout(const Duration(seconds: 15));
        }
        // A page turn during the request must remain pending, not be acknowledged.
        final acknowledge = _writes.then((_) async {
          if (prefs.getString(key) == raw) {
            await _put(prefs, id, {
              'value': newerRemote ? latest : value,
              'pending': false,
            });
          }
        });
        _writes = acknowledge.catchError((Object _) {});
        await acknowledge;
      }
    } finally {
      if (prefs
          .getKeys()
          .where((key) => key.startsWith(_prefix))
          .any((key) => _decode(prefs.getString(key))?['pending'] == true)) {
        _schedule(const Duration(seconds: 15));
      }
    }
  }

  void dispose() {
    _closed = true;
    _timer?.cancel();
  }
}
