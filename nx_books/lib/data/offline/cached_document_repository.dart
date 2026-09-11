import 'dart:async';
import 'dart:convert';

import 'package:nx_documents/nx_documents.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Network-first document storage with a persistent read-through cache.
final class CachedDocumentContentRepository
    implements DocumentContentRepository {
  CachedDocumentContentRepository({
    required this.remote,
    required this.accountKey,
    this.library,
  });

  final DocumentContentRepository remote;
  final String accountKey;
  final FileLibrary? library;
  Future<void>? _migration;
  final Map<DocumentIdentity, Future<DocumentContent?>> _downloads = {};
  int generation = 0;
  final Map<DocumentIdentity, int> _writeEpoch = {};

  String _key(DocumentIdentity identity) =>
      'nx_books.offline.$accountKey.document.${identity.modelType}.${identity.id}';

  @override
  Future<DocumentContent?> load(DocumentIdentity identity) async {
    final cached = await _read(identity);
    if (cached != null) {
      unawaited(_refreshSilently(identity));
      return cached;
    }
    return _loadRemote(identity).timeout(const Duration(seconds: 20));
  }

  /// Downloads the document once if this account has not cached it yet.
  Future<void> ensureCached(
    DocumentIdentity identity, {
    DateTime? expectedRevision,
    bool verifyContents = false,
  }) async {
    await migrateLegacy();
    final storage = library;
    if (storage != null) {
      final item = await storage.metadata(identity.modelType, '${identity.id}');
      if (item != null &&
          (expectedRevision == null ||
              item.revision == expectedRevision.toUtc().toIso8601String()) &&
          await storage.files.exists(item.reference) &&
          (!verifyContents || await _verify(identity))) {
        return;
      }
    } else if (await _verify(identity)) {
      return;
    }
    final content = await _loadRemote(
      identity,
    ).timeout(const Duration(seconds: 20));
    if (content == null) {
      throw StateError(
        'Document ${identity.modelType}/${identity.id} unavailable',
      );
    }
    if (verifyContents && !await _verify(identity)) {
      throw StateError('Downloaded document could not be verified');
    }
  }

  Future<bool> _verify(DocumentIdentity identity) async {
    try {
      return await _read(identity) != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<DocumentContent> save(DocumentContent content) async {
    generation++;
    try {
      final saved = await remote.save(content);
      await _write(saved);
      return saved;
    } finally {
      generation++;
    }
  }

  Future<bool> hasSyncedContent(DocumentIdentity identity, String hash) async {
    final item = await library?.metadata(identity.modelType, '${identity.id}');
    return item?.summary['syncHash'] == hash && await _verify(identity);
  }

  Future<void> cacheSynced(DocumentContent content, String hash) =>
      _write(content, syncHash: hash);

  Future<void> _write(DocumentContent content, {String? syncHash}) async {
    _writeEpoch.update(
      content.identity,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    final encoded = jsonEncode(<String, dynamic>{
      'title': content.title,
      'plainText': content.plainText,
      'jsonDocument': content.jsonDocument,
      'updatedAt': content.updatedAt.toUtc().toIso8601String(),
    });
    final storage = library;
    if (storage != null) {
      if (syncHash == null) {
        // A background read of identical content must not discard the last
        // server acknowledgment and force a redundant batch on the next sync.
        try {
          if (await storage.read(
                content.identity.modelType,
                '${content.identity.id}',
              ) ==
              encoded) {
            return;
          }
        } catch (_) {
          // A damaged copy still needs to be rewritten below.
        }
      }
      await storage.saveRemote(
        content.identity.modelType,
        '${content.identity.id}',
        encoded,
        summary: {
          'title': content.title,
          if (syncHash != null) 'syncHash': syncHash,
        },
        revision: content.updatedAt.toUtc().toIso8601String(),
      );
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(content.identity), encoded);
  }

  Future<DocumentContent?> _loadRemote(DocumentIdentity identity) =>
      _downloads.putIfAbsent(identity, () async {
        final startedAt = _writeEpoch[identity];
        final localGeneration = generation;
        try {
          final content = await remote
              .load(identity)
              .timeout(const Duration(seconds: 20));
          if (content != null &&
              startedAt == _writeEpoch[identity] &&
              localGeneration == generation) {
            await _write(content);
          }
          return content;
        } finally {
          _downloads.remove(identity);
        }
      });

  /// Drain the legacy preference cache once, without decoding the whole
  /// library into document objects. Each source key is removed only after its
  /// own file/index round trip succeeds; interrupted runs resume by key.
  Future<void> migrateLegacy() => _migration ??= _migrateLegacy().catchError((
    Object error,
    StackTrace stack,
  ) {
    _migration = null;
    Error.throwWithStackTrace(error, stack);
  });

  Future<void> _migrateLegacy() async {
    final storage = library;
    if (storage == null) return;
    final preferences = await SharedPreferences.getInstance();
    final prefix = 'nx_books.offline.$accountKey.document.';
    for (final key
        in preferences
            .getKeys()
            .where((key) => key.startsWith(prefix))
            .toList()) {
      final suffix = key.substring(prefix.length);
      final separator = suffix.lastIndexOf('.');
      if (separator < 1) continue;
      final type = suffix.substring(0, separator);
      final id = suffix.substring(separator + 1);
      final encoded = preferences.getString(key);
      if (encoded == null) continue;
      // Preserve any newer canonical copy. Legacy content still receives its
      // own indexed file before its preference source is removed.
      final collection = await storage.metadata(type, id) == null
          ? type
          : 'legacy_$type';
      await storage.saveRemote(collection, id, encoded);
      if (await storage.read(collection, id) == encoded) {
        await preferences.remove(key);
      }
    }
  }

  Future<void> _refreshSilently(DocumentIdentity identity) async {
    try {
      await _loadRemote(identity).timeout(const Duration(seconds: 20));
    } catch (_) {
      // The cached copy remains readable when refresh is unavailable.
    }
  }

  Future<DocumentContent?> _read(DocumentIdentity identity) async {
    final storage = library;
    String? encoded = await storage?.read(identity.modelType, '${identity.id}');
    if (encoded == null) {
      final preferences = await SharedPreferences.getInstance();
      encoded = preferences.getString(_key(identity));
      if (encoded != null && storage != null) {
        await storage.saveRemote(identity.modelType, '${identity.id}', encoded);
        if (await storage.read(identity.modelType, '${identity.id}') ==
            encoded) {
          await preferences.remove(_key(identity));
        }
      }
    }
    if (encoded == null) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      final json = Map<String, dynamic>.from(decoded);
      final document = json['jsonDocument'];
      return DocumentContent(
        identity: identity,
        title: json['title']?.toString() ?? '',
        plainText: json['plainText']?.toString() ?? '',
        jsonDocument: document is Map
            ? Map<String, dynamic>.from(document)
            : const <String, dynamic>{},
        updatedAt:
            DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    } catch (_) {
      return null;
    }
  }
}
