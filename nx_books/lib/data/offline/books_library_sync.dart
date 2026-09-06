import 'package:nx_documents/nx_documents.dart';
import 'package:nx_offline/nx_offline.dart';
import 'cached_document_repository.dart';

/// The catalog contains headers only; bodies are checked and saved one at a
/// time so a large library does not remain decoded in memory.
class BooksLibraryPull implements PullReconciler<DocumentIdentity> {
  BooksLibraryPull({required this.discover, required this.repository});

  final Future<Map<DocumentIdentity, DateTime?>> Function() discover;
  final CachedDocumentContentRepository repository;

  @override
  Future<void> pullAll() async {
    final revisions = await discover();
    await pullLibrary<DocumentIdentity>(
      discover: () async => revisions.keys,
      reconcilePage: (page) async {
        for (final identity in page) {
          await repository.ensureCached(
            identity,
            expectedRevision: revisions[identity],
          );
        }
      },
    );
  }

  @override
  Future<void> pullKeys(Set<DocumentIdentity> keys) async {
    for (final identity in keys) {
      await repository.ensureCached(identity);
    }
  }
}
