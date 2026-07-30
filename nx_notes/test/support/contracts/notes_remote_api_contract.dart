import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/ports/notes_remote_api.dart';
import 'package:nx_notes/domain/catalog/catalog_query.dart';
import 'package:nx_notes/domain/sync/remote_save_result.dart';

typedef NotesRemoteApiFactory = Future<NotesRemoteApi> Function();

void runNotesRemoteApiContract({required NotesRemoteApiFactory createApi}) {
  late NotesRemoteApi api;

  setUp(() async {
    api = await createApi();
  });

  test('catalog requests return summaries and full bodies stay lazy', () async {
    final summaries = await api.fetchCatalog(const CatalogQuery.recent());

    expect(summaries, isNotEmpty);
    final full = await api.fetchDocument(summaries.first.id);
    expect(full, isNotNull);
    expect(full!.hasFullDocument, isTrue);
  });

  test('newer save applies and an equal retry is stale', () async {
    final summary = (await api.fetchCatalog(const CatalogQuery.recent())).first;
    final current = (await api.fetchDocument(summary.id))!;
    final edited = current.copyWith(
      document: 'newer content',
      updatedAt: current.updatedAt.add(const Duration(minutes: 1)),
    );

    final applied = await api.saveDocumentIfNewer(edited);
    final retry = await api.saveDocumentIfNewer(edited);

    expect(applied.status, RemoteSaveStatus.applied);
    expect(retry.status, RemoteSaveStatus.stale);
  });

  test('create and delete round trip', () async {
    final created = await api.createDocument(title: 'Created by contract');
    expect((await api.fetchDocument(created.id))!.title, 'Created by contract');

    await api.deleteDocument(created.id);
    expect(await api.fetchDocument(created.id), isNull);
  });
}
