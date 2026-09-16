import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reading position is device-local UI state, never document content.
final documentScrollStoreProvider = Provider<DocumentScrollStore?>((ref) {
  final user = ref.watch(authProvider).value;
  if (user?.domainId == null) return null;
  return DocumentScrollStore(user!.storageKey);
});

class DocumentScrollStore {
  const DocumentScrollStore(this.scope);
  final String scope;

  String key(String modelType, int documentId) =>
      'nx_docs.scroll.v1:${jsonEncode([scope, modelType, documentId])}';

  Future<Map<String, dynamic>?> read(String modelType, int documentId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(key(modelType, documentId));
      return raw == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(
    String modelType,
    int documentId,
    Map<String, Object> anchor,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        key(modelType, documentId),
        jsonEncode(anchor),
      );
    } catch (_) {
      // A failed preference write must not affect document editing or sync.
    }
  }
}
