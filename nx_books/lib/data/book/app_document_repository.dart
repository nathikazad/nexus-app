import 'package:nx_db/app_reads.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_documents/nx_documents.dart';

final class AppBookDocumentRepository
    implements DocumentContentRepository, DocumentContentUpdates {
  AppBookDocumentRepository(this.reads, this.mutations);
  final AppReads? reads;
  final DocumentContentRepository mutations;
  @override
  Stream<void> get changes => reads?.changes ?? const Stream.empty();
  @override
  Future<DocumentContent?> load(DocumentIdentity identity) async {
    try {
      return documentContentFromModel(
        identity,
        Model.fromJson(
          await (reads ?? (throw StateError('Connect to load this document')))
              .read('${identity.id}'),
        ),
      );
    } on AppReadException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<DocumentContent> save(DocumentContent content) async {
    final saved = await mutations.save(content);
    reads?.invalidate();
    return saved;
  }
}
