import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_docs/companion/note_companion.dart';
import 'package:nx_docs/documents/browser/document_browser.dart';
import 'package:nx_docs/documents/document_data_providers.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/documents/editor/document_editor_view.dart';
import 'package:nx_docs/sync/fake/fake_document_workspace.dart';
import 'package:nx_docs/workspace/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('browser and nested links retain the originating companion', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final workspace = FakeDocumentWorkspace(
      documents: [_document(1), _document(2)],
    );
    addTearDown(workspace.close);
    DocumentBrowser? browser;
    var selected = 1;
    late StateSetter selectDocument;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userIdProvider.overrideWithValue(null),
          sockWsUrlProvider.overrideWithValue(null),
          imageBaseUrlProvider.overrideWithValue(null),
          documentImageAssetServiceProvider.overrideWithValue(null),
          documentWorkspaceProvider.overrideWithValue(workspace),
          documentBrowserBuilderProvider.overrideWithValue((value) {
            browser = value;
            return const ColoredBox(color: Colors.white);
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                selectDocument = setState;
                return DocumentEditorView(
                  documentId: selected,
                  onOpenDocumentLink: (id) =>
                      selectDocument(() => selected = id),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final original = tester.state(find.byType(NoteCompanion));
    await tester.tap(find.byTooltip('Ask AI about this note'));
    await tester.pumpAndSettle();
    final editor = tester.widget<DocumentEditorBody>(
      find.byType(DocumentEditorBody),
    );
    editor.onOpenWebLink!(Uri.parse('https://example.org/article-a'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(NoteCompanion)), same(original));
    expect(
      find.byKey(const ValueKey('note-companion-chat-panel')),
      findsOneWidget,
    );
    expect(
      tester.widget<NoteCompanion>(find.byType(NoteCompanion)).document.id,
      1,
    );
    browser!.onArticleChanged(
      BrowserArticle(
        url: Uri.parse('https://example.org/article-b'),
        title: 'B',
        text: 'Article B',
      ),
    );
    await tester.pump();
    expect(
      tester.widget<NoteCompanion>(find.byType(NoteCompanion)).article!.text,
      'Article B',
    );
    expect(tester.state(find.byType(NoteCompanion)), same(original));
    browser!.onClose();
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(NoteCompanion)), same(original));
    expect(
      tester.widget<NoteCompanion>(find.byType(NoteCompanion)).browserOpen,
      isFalse,
    );
    editor.onOpenWebLink!(Uri.parse('https://example.org/article-c'));
    await tester.pumpAndSettle();
    browser!.onOpenDocument(2);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NoteCompanion>(find.byType(NoteCompanion)).document.id,
      2,
    );
    expect(tester.state(find.byType(NoteCompanion)), isNot(same(original)));
    expect(
      tester.widget<NoteCompanion>(find.byType(NoteCompanion)).browserOpen,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  test('article extraction failures cannot become context', () {
    final article = BrowserArticle.fromExtraction(
      Uri.parse('https://example.org'),
      null,
    );
    expect(article.error, isNotNull);
    expect(() => article.context, throwsStateError);
  });
}

NxDocument _document(int id) => NxDocument(
  id: id,
  title: 'Document $id',
  modelTypeName: 'Document',
  document: 'Read this document.',
  jsonDocument: const {},
  wordCount: 3,
  topics: const [],
  areaTags: const [],
  tagsBySystem: const {},
  pinned: false,
  updatedAt: DateTime.utc(2026),
  updatedLabel: 'now',
  versionNumber: 1,
  excerpt: 'Read this document.',
  links: const [],
);
