import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_docs/sync/native/native_document_workspace.dart';
import 'package:nx_docs/sync/sync_providers.dart';
import 'package:nx_docs/sync/web/web_document_workspace.dart';
import 'package:nx_docs/workspace/last_opened_document_store.dart';
import 'package:nx_docs/workspace/document_workspace.dart';
import 'package:nx_docs/workspace/preferences_last_opened_document_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

final lastOpenedDocumentStoreProvider = FutureProvider<LastOpenedDocumentStore>(
  (ref) async {
    final preferences = await SharedPreferences.getInstance();
    return PreferencesLastOpenedDocumentStore(preferences);
  },
);

final documentWorkspaceProvider = Provider<DocumentWorkspace?>((ref) {
  final remote = ref.watch(documentRemoteApiProvider);
  final DocumentWorkspace? workspace;
  if (ref.watch(offlineEnabledProvider)) {
    final local = ref.watch(localNotesStoreProvider);
    final uploader = ref.watch(backgroundUploaderProvider);
    final synchronizer = ref.watch(documentSynchronizerProvider);
    if (local == null || uploader == null || synchronizer == null) return null;
    workspace = NativeDocumentWorkspace(
      localStore: local,
      remoteApi: remote,
      uploader: uploader,
      synchronizer: synchronizer,
      clock: ref.watch(offlineClockProvider),
      idGenerator: ref.watch(offlineIdGeneratorProvider),
    );
  } else {
    workspace = WebDocumentWorkspace(remoteApi: remote);
  }
  ref.onDispose(() => unawaited(workspace!.close()));
  return workspace;
});
