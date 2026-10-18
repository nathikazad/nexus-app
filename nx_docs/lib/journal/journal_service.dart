import 'dart:async';
import 'package:nx_docs/library/models/catalog_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:nx_docs/workspace/document_workspace.dart';
import 'package:nx_docs/workspace/workspace_providers.dart';

final journalServiceProvider = Provider<JournalService?>((ref) {
  final workspace = ref.watch(documentWorkspaceProvider);
  if (workspace == null) return null;
  final service = JournalService(workspace);
  ref.onDispose(service.dispose);
  return service;
});

class JournalService {
  JournalService(this.workspace);
  final DocumentWorkspace workspace;
  bool _disposed = false;
  void dispose() => _disposed = true;
  final Map<String, Future<NxDocument>> _pending = {};

  Future<NxDocument> openDate(DateTime date, {required String title}) {
    final day = DateTime(date.year, date.month, date.day);
    final key = journalDateKey(day);
    return _pending.putIfAbsent(
      key,
      () => _open(day, title).whenComplete(() {
        _pending.remove(key);
      }),
    );
  }

  Future<NxDocument> _open(DateTime day, String title) async {
    const query = CatalogQuery.all();
    Future<List<DocumentSummary>> matches() async {
      final ready = Completer<CatalogState>();
      final subscription = workspace
          .watchCatalog(query)
          .listen(
            (value) {
              if (!ready.isCompleted &&
                  !value.isInitialLoading &&
                  !value.isRefreshing) {
                ready.complete(value);
              }
            },
            onError: (Object error, StackTrace stack) {
              if (!ready.isCompleted) ready.completeError(error, stack);
            },
            onDone: () {
              if (!ready.isCompleted) {
                ready.completeError(StateError('Journal workspace closed'));
              }
            },
          );
      // Read the current value without waiting for a shared catalog stream's
      // cancellation lifecycle (the calendar itself continues observing it).
      final catalog = await ready.future.whenComplete(() {
        unawaited(subscription.cancel());
      });
      if (_disposed) throw StateError('Journal domain changed');
      final found =
          catalog.items
              .where(
                (entry) =>
                    entry.isJournalEntry &&
                    entry.journalDate != null &&
                    journalDateKey(entry.journalDate!) == journalDateKey(day),
              )
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id));
      if (found.isEmpty && catalog.error != null) throw catalog.error!;
      return found;
    }

    // Existing cached entries remain available offline.
    final cached = await matches();
    if (cached.isNotEmpty) return cached.first.toDocument();
    // Never create from an incomplete/offline catalog: another device may
    // already have created this date. Uniqueness remains a UI convention.
    await workspace.refreshCatalog(query);
    final refreshed = await matches();
    if (refreshed.isNotEmpty) return refreshed.first.toDocument();
    return workspace.createDocument(
      title: title,
      kind: DocumentKind.journalEntry,
      journalDate: day,
    );
  }
}
