import 'package:nx_db/documents.dart';
import 'package:nx_documents/nx_documents.dart';
import 'package:nx_offline/nx_offline.dart';
import '../../domain/book/download_report.dart';
import 'books_sync_store.dart';

abstract interface class BooksSyncTransport {
  Future<DocumentSyncResponse> manifest();
  Future<DocumentSyncResponse> download(Set<int> ids);
}

/// Stateless pull: one manifest request; one batch for missing/mismatched items.
/// Local integrity checks still run even if every server hash matches.
final class BooksHashPull implements PullReconciler<DocumentIdentity> {
  BooksHashPull({
    required this.transport,
    required this.store,
    this.reportStore,
    this.onChanged,
    this.pullBookFiles,
  });
  final BooksSyncTransport transport;
  final BooksSyncStore store;
  final DownloadReportStore? reportStore;
  final void Function()? onChanged;
  final Future<void> Function()? pullBookFiles;

  Future<void> _report(
    DownloadPhase phase,
    int total,
    int verified,
    List<String> failed,
  ) async {
    await reportStore?.save(
      DownloadReport(
        phase: phase,
        total: total,
        verified: verified,
        failed: List.unmodifiable(failed),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    onChanged?.call();
  }

  @override
  Future<void> pullAll() async {
    var total = 0;
    var verified = 0;
    final failed = <String>[];
    await _report(DownloadPhase.checking, total, verified, failed);
    try {
      final catalogGeneration = store.catalog.generation;
      final remote = await transport.manifest();
      final manifest = [...remote.manifest];
      if (manifest.map((entry) => entry.id).toSet().length != manifest.length) {
        throw StateError('Duplicate documents in server manifest');
      }
      total = manifest.length;
      final missing = <int>{};
      for (final entry in manifest) {
        if (await store.verified(entry)) {
          verified++;
        } else {
          missing.add(entry.id);
        }
      }
      await _report(DownloadPhase.downloading, total, verified, failed);
      if (missing.isNotEmpty) {
        final generation = store.histories.generation;
        final documentGeneration = store.documents.generation;
        final bundle = await transport.download(missing);
        final received = <int>{};
        for (final entry in bundle.documents) {
          if (!missing.contains(entry.documentId) ||
              !received.add(entry.documentId)) {
            throw StateError('Unexpected document in sync response');
          }
          try {
            await store.apply(entry, generation, documentGeneration);
            verified++;
          } catch (_) {
            failed.add('${entry.documentId}');
          }
          if (received.length % 25 == 0) {
            await _report(DownloadPhase.downloading, total, verified, failed);
          }
        }
        for (final id in missing.difference(received)) {
          // A deletion between the two requests is legitimate. Anything else
          // is an incomplete response and must not certify offline readiness.
          if (bundle.deletedIds.contains(id)) {
            manifest.removeWhere((e) => e.id == id);
            total--;
          } else {
            failed.add('$id');
          }
        }
      }
      if (failed.isNotEmpty) {
        throw StateError('${failed.length} items could not be saved');
      }
      await store.publish(manifest, remote.topicTags, catalogGeneration);
      await pullBookFiles?.call();
      await _report(DownloadPhase.complete, total, verified, failed);
    } catch (_) {
      await _report(DownloadPhase.incomplete, total, verified, failed);
      rethrow;
    }
  }

  @override
  Future<void> pullKeys(Set<DocumentIdentity> keys) => pullAll();
}
