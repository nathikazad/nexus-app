import 'dart:convert';
import 'package:nx_documents/nx_documents.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReadingPositionStore {
  const ReadingPositionStore(this.account);
  final String account;
  String _key(DocumentIdentity id) =>
      'nx_books.$account.position.${id.modelType}.${id.id}';

  Future<ReadingPosition?> load(DocumentIdentity id) async {
    final raw = (await SharedPreferences.getInstance()).getString(_key(id));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map;
      final index = json['index'] as int;
      final alignment = (json['alignment'] as num).toDouble();
      if (index < 0 || !alignment.isFinite || alignment > 1) return null;
      return ReadingPosition(index: index, alignment: alignment);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(DocumentIdentity id, ReadingPosition position) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      _key(id),
      jsonEncode({'index': position.index, 'alignment': position.alignment}),
    )) {
      throw StateError('Reading position could not be saved');
    }
  }
}
