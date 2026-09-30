import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shares browser visibility with the surrounding document chrome. Each mounted
/// document owns its browser, and the state expires when its readers go away.
final documentBrowserSessionProvider = NotifierProvider.autoDispose
    .family<DocumentBrowserSession, Uri?, int>(DocumentBrowserSession.new);

class DocumentBrowserSession extends Notifier<Uri?> {
  DocumentBrowserSession(this.documentId);

  final int documentId;

  @override
  Uri? build() => null;

  void open(Uri url) => state = url;
  void close() => state = null;
}
