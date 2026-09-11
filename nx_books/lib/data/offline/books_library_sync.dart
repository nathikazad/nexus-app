import 'package:nx_documents/nx_documents.dart';
import 'package:nx_offline/nx_offline.dart';
import 'cached_document_repository.dart';
import '../../domain/book/download_report.dart';

/// The catalog contains headers only; bodies are checked and saved one at a
/// time so a large library does not remain decoded in memory.
class BooksLibraryPull implements PullReconciler<DocumentIdentity> {
  BooksLibraryPull({
    required this.discover,
    required this.repository,
    this.reportStore,
    this.onReportChanged,
    this.pullBookFiles,
  });

  final Future<Map<DocumentIdentity, DateTime?>> Function() discover;
  final CachedDocumentContentRepository repository;
  final DownloadReportStore? reportStore;
  final void Function()? onReportChanged;
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
    onReportChanged?.call();
  }

  @override
  Future<void> pullAll() async {
    final previous = await reportStore?.load();
    await _report(
      DownloadPhase.checking,
      previous?.total ?? 0,
      previous?.verified ?? 0,
      previous?.failed ?? [],
    );
    late Map<DocumentIdentity, DateTime?> revisions;
    try {
      revisions = await discover();
    } catch (_) {
      await _report(
        DownloadPhase.incomplete,
        previous?.total ?? 0,
        previous?.verified ?? 0,
        previous?.failed ?? [],
      );
      rethrow;
    }
    var verified = 0;
    final failures = <String>[];
    await _report(DownloadPhase.downloading, revisions.length, 0, failures);
    await pullLibrary<DocumentIdentity>(
      discover: () async => revisions.keys,
      reconcilePage: (page) async {
        for (final identity in page) {
          try {
            await repository.ensureCached(
              identity,
              expectedRevision: revisions[identity],
              verifyContents: true,
            );
            verified++;
          } catch (_) {
            failures.add('${identity.modelType}/${identity.id}');
          }
          await _report(
            DownloadPhase.downloading,
            revisions.length,
            verified,
            failures,
          );
        }
      },
    );
    await _report(
      failures.isEmpty ? DownloadPhase.complete : DownloadPhase.incomplete,
      revisions.length,
      verified,
      failures,
    );
    if (failures.isNotEmpty) {
      throw StateError('${failures.length} documents could not be verified');
    }
    await pullBookFiles?.call();
  }

  @override
  Future<void> pullKeys(Set<DocumentIdentity> keys) async {
    for (final identity in keys) {
      await repository.ensureCached(identity);
    }
  }
}
