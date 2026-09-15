import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_documents/nx_documents.dart';

void main() {
  testWidgets(
    'remote updates preserve the displayed page and cannot replace a pending edit',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentReaderHost(
              identity: repository.content.identity,
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      DocumentReader reader() =>
          tester.widget<DocumentReader>(find.byType(DocumentReader));
      final remote = Completer<DocumentContent?>();
      repository.next = remote.future;
      repository.events.add(null);
      await tester.pump();
      expect(reader().content.plainText, 'Original');
      expect(find.byType(CircularProgressIndicator), findsNothing);
      remote.complete(repository.content.copyWith(plainText: 'Remote'));
      await tester.pumpAndSettle();
      expect(reader().content.plainText, 'Remote');

      repository.saveGate = Completer<DocumentContent>();
      final draft = repository.content.copyWith(plainText: 'My draft');
      final save = reader().onChanged(draft);
      await tester.pump();
      final before = repository.loads;
      repository.events.add(null);
      await tester.pump();
      expect(repository.loads, before);
      expect(reader().content.plainText, 'My draft');
      repository.saveGate!.complete(draft);
      await save;
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await repository.events.close();
    },
  );
}

class _Repository implements DocumentContentRepository, DocumentContentUpdates {
  final events = StreamController<void>.broadcast();
  @override
  Stream<void> get changes => events.stream;
  final content = DocumentContent(
    identity: const DocumentIdentity(id: 1, modelType: 'Book'),
    title: 'Book',
    plainText: 'Original',
    jsonDocument: const {},
    updatedAt: DateTime.utc(2026),
  );
  Future<DocumentContent?>? next;
  Completer<DocumentContent>? saveGate;
  int loads = 0;
  @override
  Future<DocumentContent?> load(DocumentIdentity identity) async {
    loads++;
    return next ?? Future.value(content);
  }

  @override
  Future<DocumentContent> save(DocumentContent content) async =>
      saveGate?.future ?? Future.value(content);
}
