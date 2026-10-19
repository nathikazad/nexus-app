import 'dart:async';
import 'package:flutter/foundation.dart';
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
  JournalService(this.workspace) {
    // Keep one catalog subscription alive across date taps.
    _catalogSubscription = workspace
        .watchCatalog(const CatalogQuery.all())
        .listen((_) {}, onError: (Object _) {});
  }
  late final StreamSubscription<CatalogState> _catalogSubscription;
  Future<void>? _refresh;
  Future<void> refresh({bool force = false}) {
    if (force) _refresh = null;
    return _refresh ??= workspace
        .refreshCatalog(const CatalogQuery.all())
        .catchError((Object error) {
          _refresh = null;
          throw error;
        });
  }

  final DocumentWorkspace workspace;
  bool _disposed = false;
  void dispose() {
    _disposed = true;
    unawaited(_catalogSubscription.cancel());
  }

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
    final timer = Stopwatch()..start();
    void mark(String stage) => debugPrint(
      '[NX Journal open] date=${journalDateKey(day)} stage=$stage elapsed_ms=${timer.elapsedMilliseconds}',
    );
    mark('start');
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
    mark('catalog_lookup');
    if (cached.isNotEmpty) {
      mark('existing');
      return cached.first.toDocument();
    }
    // Reuse the calendar's completed refresh instead of downloading the entire
    // catalog on every empty-date tap. Failed refreshes still prevent creation;
    // per-date uniqueness remains a UI convention across devices.
    mark('refresh_start');
    await refresh();
    mark('refresh_end');
    final refreshed = await matches();
    if (refreshed.isNotEmpty) return refreshed.first.toDocument();
    mark('create_start');
    final created = await workspace.createDocument(
      title: title,
      kind: DocumentKind.journalEntry,
      journalDate: day,
    );
    mark('create_end');
    return created;
  }
}
