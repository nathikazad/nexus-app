import 'dart:convert';
import 'package:nx_documents/nx_documents.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import '../../domain/book/reading_history.dart';

/// Account-scoped snapshots; never an upload queue for AI requests.
class ReadingHistoryStore {
  ReadingHistoryStore(this.library);
  final FileLibrary library;
  int generation = 0;
  final Map<String, String> _lastWrites = {};
  String _key(DocumentIdentity id) => '${id.modelType}_${id.id}';

  Future<ReadingHistory?> load(DocumentIdentity id) async {
    try {
      final raw = await library.read('reading_history', _key(id));
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map;
      return ReadingHistory(json['title'] as String, [
        for (final message in json['messages'] as List)
          ReadingMessage(
            message['role'] as String,
            message['text'] as String,
            turn: message['turn'] as String?,
          ),
      ]);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(
    DocumentIdentity id,
    ReadingHistory history, {
    bool local = true,
  }) async {
    final raw = jsonEncode({
      'title': history.title,
      'messages': [
        for (final m in history.messages)
          {'role': m.role, 'text': m.text, 'turn': m.turn},
      ],
    });
    final key = _key(id);
    if (_lastWrites[key] == raw) {
      try {
        if (await library.read('reading_history', key) == raw) return;
      } catch (_) {
        // The remembered write is not proof that its file is still intact.
      }
    }
    if (local) generation++;
    _lastWrites[key] = raw;
    try {
      await library.saveRemote('reading_history', key, raw);
    } catch (_) {
      if (_lastWrites[key] == raw) _lastWrites.remove(key);
      rethrow;
    }
  }

  Future<bool> saveDownloaded(
    DocumentIdentity id,
    ReadingHistory history,
    int startedAt,
  ) async {
    final old = await load(id);
    // Do not replace a conversation changed while the remote fetch was running,
    // or discard a locally received tail the server has not yet persisted.
    if (generation != startedAt ||
        (old?.messages.length ?? 0) > history.messages.length) {
      return false;
    }
    await save(id, history, local: false);
    return true;
  }
}
