import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/documents/data/kgql/document_mapper.dart';
import 'package:nx_docs/journal/journal_calendar.dart';
import 'package:nx_docs/journal/journal_service.dart';
import 'package:nx_docs/sync/fake/fake_document_remote_api.dart';
import 'package:nx_docs/sync/native/drift_document_mapper.dart';
import 'package:nx_docs/sync/web/web_document_workspace.dart';
import 'package:nx_docs/workspace/workspace_providers.dart';

void main() {
  test(
    'journal creation and summaries preserve calendar dates through storage',
    () {
      final date = DateTime(2028, 2, 29);
      final request = setModelRequestForCreateDocument(
        kind: DocumentKind.journalEntry,
        journalDate: date,
      ).toJson();
      expect(request['model_type'], 'Journal Entry');
      expect(
        request['attributes'],
        contains(equals({'key': 'journal_date', 'value': '2028-02-29'})),
      );
      expect(
        () => setModelRequestForCreateDocument(kind: DocumentKind.journalEntry),
        throwsArgumentError,
      );
      final document = documentFromModel(
        Model.fromJson({
          'id': 42,
          'name': 'Leap day',
          'model_type': {'id': 99, 'name': 'Journal Entry'},
          'attributes': {'journal_date': '2028-02-29T00:00:00'},
        }),
      );
      final summary = DocumentSummary.fromDocument(document).toDocument();
      const mapper = DriftDocumentMapper();
      final restored = mapper.documentFromJsonString(
        mapper.documentToJsonString(summary),
      );
      expect(restored.journalDate, date);
      expect(restored.copyWith(title: 'Edited').journalDate, date);
      expect(restored.isJournalEntry, isTrue);
    },
  );

  test(
    'repeated taps and revisits open one immediately-created empty entry',
    () async {
      final remote = FakeDocumentRemoteApi();
      final workspace = WebDocumentWorkspace(remoteApi: remote);
      addTearDown(workspace.close);
      final service = JournalService(workspace);
      final date = DateTime(2026, 10, 17);
      final first = service.openDate(date, title: 'October 17, 2026');
      final second = service.openDate(date, title: 'October 17, 2026');
      expect(identical(first, second), isTrue);
      final created = await first;
      expect(created.isJournalEntry, isTrue);
      expect(created.journalDate, date);
      expect(created.document, isEmpty);
      expect((await service.openDate(date, title: 'same date')).id, created.id);
      expect(remote.documents, hasLength(1));
    },
  );

  test('failed calendar reads cannot create an entry', () async {
    final remote = FakeDocumentRemoteApi(error: StateError('offline'));
    final workspace = WebDocumentWorkspace(remoteApi: remote);
    addTearDown(workspace.close);
    await expectLater(
      JournalService(workspace).openDate(DateTime(2026), title: 'test'),
      throwsStateError,
    );
    expect(remote.documents, isEmpty);
  });

  test('domain disposal during a read prevents creation', () async {
    final gate = Completer<void>();
    final remote = FakeDocumentRemoteApi(catalogBarrier: gate.future);
    final workspace = WebDocumentWorkspace(remoteApi: remote);
    addTearDown(workspace.close);
    final service = JournalService(workspace);
    final pending = service.openDate(DateTime(2026), title: 'test');
    final expectation = expectLater(pending, throwsStateError);
    service.dispose();
    gate.complete();
    await expectation;
    expect(remote.documents, isEmpty);
  });

  for (final width in [256.0, 390.0]) {
    testWidgets(
      'calendar at $width marks dates and navigates months and years',
      (tester) async {
        final date = DateTime(DateTime.now().year, DateTime.now().month, 12);
        final existing = documentForCreatedId(
          42,
          kind: DocumentKind.journalEntry,
          journalDate: date,
        );
        final remote = FakeDocumentRemoteApi(documents: [existing]);
        final workspace = WebDocumentWorkspace(remoteApi: remote);
        addTearDown(workspace.close);
        int? opened;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [documentWorkspaceProvider.overrideWithValue(workspace)],
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: width,
                  child: JournalCalendar(onOpen: (id) => opened = id),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final day = find.byKey(ValueKey('journal-day-${journalDateKey(date)}'));
        expect(day, findsOneWidget);
        final marked = tester.widget<Material>(
          find.ancestor(of: day, matching: find.byType(Material)).first,
        );
        final emptyDay = find.byKey(
          ValueKey(
            'journal-day-${journalDateKey(DateTime(date.year, date.month, 13))}',
          ),
        );
        final empty = tester.widget<Material>(
          find.ancestor(of: emptyDay, matching: find.byType(Material)).first,
        );
        expect(marked.color, isNot(empty.color));
        await tester.tap(day);
        await tester.pumpAndSettle();
        expect(opened, 42);
        expect(remote.documents, hasLength(1));
        await tester.tap(emptyDay);
        await tester.pumpAndSettle();
        expect(remote.documents, hasLength(2));
        expect(remote.documents.last.document, isEmpty);
        await tester.tap(find.byKey(const Key('journal-calendar-heading')));
        await tester.pumpAndSettle();
        expect(find.text('${date.year}'), findsOneWidget);
        await tester.tap(find.byKey(const Key('journal-calendar-heading')));
        await tester.pumpAndSettle();
        expect(find.text('${date.year}'), findsOneWidget);
        await tester.tap(find.text('${date.year}'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Next'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
