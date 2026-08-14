import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_docs/documents/document_data_providers.dart';
import 'package:nx_docs/documents/document_history.dart';
import 'package:nx_docs/documents/document_links.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/documents/document_session.dart';
import 'package:nx_docs/workspace/workspace_providers.dart';

final documentHistoryServiceProvider = Provider<DocumentHistoryService?>((ref) {
  final workspace = ref.watch(documentWorkspaceProvider);
  if (workspace == null) return null;
  return DocumentHistoryService(
    repository: ref.watch(documentRepositoryProvider),
    workspace: workspace,
  );
});

final documentLinkServiceProvider = Provider<DocumentLinkService?>((ref) {
  final workspace = ref.watch(documentWorkspaceProvider);
  if (workspace == null) return null;
  return DocumentLinkService(
    repository: ref.watch(documentRepositoryProvider),
    workspace: workspace,
  );
});

final documentSessionProvider = Provider.autoDispose
    .family<DocumentSession?, int>((ref, documentId) {
      final workspace = ref.watch(documentWorkspaceProvider);
      if (workspace == null) return null;
      final session = workspace.openDocument(documentId);
      ref.onDispose(() => unawaited(session.close()));
      return session;
    });

final documentSessionStateProvider = StreamProvider.autoDispose
    .family<DocumentSessionState, int>((ref, documentId) async* {
      final session = ref.watch(documentSessionProvider(documentId));
      if (session == null) {
        yield const DocumentSessionState();
        return;
      }
      yield* _sessionStates(session);
    });

final documentDemandProvider = FutureProvider.autoDispose.family<void, int>((
  ref,
  documentId,
) async {
  final workspace = ref.watch(documentWorkspaceProvider);
  if (workspace == null) return;
  await workspace.ensureDocumentAvailable(documentId);
});

final offlineDocumentProvider = StreamProvider.family<NxDocument?, int>((
  ref,
  documentId,
) async* {
  final session = ref.watch(documentSessionProvider(documentId));
  if (session == null) {
    yield null;
    return;
  }
  await for (final state in _sessionStates(session)) {
    yield state.document;
  }
});

Stream<DocumentSessionState> _sessionStates(DocumentSession session) {
  late StreamSubscription<DocumentSessionState> subscription;
  return Stream<DocumentSessionState>.multi((controller) {
    subscription = session.states.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.add(session.state);
    controller.onCancel = subscription.cancel;
  });
}
