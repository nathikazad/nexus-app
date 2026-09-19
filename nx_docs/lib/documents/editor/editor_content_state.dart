part of 'document_editor_view.dart';

class _EditorFindBarPresentation {
  const _EditorFindBarPresentation({
    required this.searchService,
    required this.onClose,
    required this.serial,
  });

  final SearchServiceV3 searchService;
  final VoidCallback onClose;
  final int serial;
}

bool _isRemoteOrigin(DocumentChangeOrigin origin) {
  return origin == DocumentChangeOrigin.initialRemoteLoad ||
      origin == DocumentChangeOrigin.remoteRefresh ||
      origin == DocumentChangeOrigin.snapshotRestore;
}

String _contentFingerprint(NxDocument document) {
  final appFlowyDocument = document.jsonDocument['document'];
  return appFlowyDocument == null
      ? document.document
      : jsonEncode(appFlowyDocument);
}
