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
    this.onCatalogChanged,
    this.pullBookFiles,
  });
  final BooksSyncTransport transport;
  final BooksSyncStore store;
  final DownloadReportStore? reportStore;
  final void Function()? onChanged;
  final void Function()? onCatalogChanged;
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
      // Capture local edit generations immediately before the download.
      var generation = store.histories.generation;
      var documentGeneration = store.documents.generation;
      final manifest =
          await reconcileHashManifest<
            int,
            DocumentHashEntry,
            DocumentSyncEntry
          >(
            manifest: remote.manifest,
            keyOf: (entry) => entry.id,
            valueKeyOf: (entry) => entry.documentId,
            verified: store.verified,
            matchesEntry: (entry, value) =>
                !entry.hash.startsWith('s1:') || entry.hash == value.syncHash,
            download: (ids) async {
              generation = store.histories.generation;
              documentGeneration = store.documents.generation;
              final bundle = await transport.download(ids);
              return HashDownload(
                bundle.documents,
                deleted: bundle.deletedIds.toSet(),
              );
            },
            applyBatch: (page) async => [
              for (final id in await store.applyBatch(
                page,
                generation,
                documentGeneration,
              ))
                int.parse(id),
            ],
            report: (downloading, count, done, failures) async {
              total = count;
              verified = done;
              failed
                ..clear()
                ..addAll(failures.map((id) => '$id'));
              await _report(
                downloading
                    ? DownloadPhase.downloading
                    : DownloadPhase.checking,
                total,
                verified,
                failed,
              );
            },
          );
      await store.publish(manifest, remote.topicTags, catalogGeneration);
      onCatalogChanged?.call();
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
