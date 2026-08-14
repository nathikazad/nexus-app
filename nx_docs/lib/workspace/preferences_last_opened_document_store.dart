import 'package:nx_docs/workspace/last_opened_document_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesLastOpenedDocumentStore implements LastOpenedDocumentStore {
  PreferencesLastOpenedDocumentStore(this.preferences);

  static const String keyPrefix = 'nx_notes.last_opened_document.';

  final SharedPreferences preferences;

  @override
  Future<int?> load(String accountKey) async {
    final documentId = preferences.getInt(_key(accountKey));
    return documentId != null && documentId > 0 ? documentId : null;
  }

  @override
  Future<void> save(String accountKey, int documentId) async {
    if (documentId <= 0) return;
    await preferences.setInt(_key(accountKey), documentId);
  }

  @override
  Future<void> clear(String accountKey) async {
    await preferences.remove(_key(accountKey));
  }

  String _key(String accountKey) =>
      '$keyPrefix${Uri.encodeComponent(accountKey)}';
}
