import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/document_session.dart';
import 'package:nx_notes/application/fake/fake_notes_workspace.dart';
import 'package:nx_notes/composition/notes_composition.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/features/editor/document_editor_view.dart';

void main() {
  testWidgets(
    'narrow read-only editor exposes no controls or software keyboard',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentImageAssetServiceProvider.overrideWithValue(null),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DocumentEditorBody(document: _document(), readOnly: true),
            ),
          ),
        ),
      );
      await tester.pump();

      final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
      expect(editor.editable, isFalse);
      expect(editor.disableKeyboardService, isTrue);
      expect(find.byType(FloatingToolbar), findsNothing);
      expect(find.byKey(const ValueKey<String>('mode-toggle')), findsNothing);

      await tester.tap(find.byType(AppFlowyEditor));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.tap(find.byKey(const ValueKey<String>('title-display-1')));
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('wide read-only editor retains desktop keyboard service', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [documentImageAssetServiceProvider.overrideWithValue(null)],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)),
            child: Scaffold(
              body: DocumentEditorBody(document: _document(), readOnly: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
    expect(editor.editable, isFalse);
    expect(editor.disableKeyboardService, isFalse);
  });

  testWidgets('reader can omit its in-document title', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [documentImageAssetServiceProvider.overrideWithValue(null)],
        child: MaterialApp(
          home: Scaffold(
            body: DocumentEditorBody(
              document: _document(),
              readOnly: true,
              showDocumentTitle: false,
              horizontalPadding: 16,
              contentTopPadding: 12,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('title-display-1')), findsNothing);
    expect(find.byType(AppFlowyEditor), findsOneWidget);
  });

  testWidgets('editor disposal does not notify while the tree is locked', (
    tester,
  ) async {
    documentActiveHeadingNotifier.value = const DocumentActiveHeading(
      documentId: 1,
      blockIndex: 0,
    );
    addTearDown(() {
      documentActiveHeadingNotifier.value = null;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [documentImageAssetServiceProvider.overrideWithValue(null)],
        child: MaterialApp(
          home: Row(
            children: <Widget>[
              Expanded(
                child: DocumentEditorBody(
                  document: _document(),
                  readOnly: true,
                ),
              ),
              ValueListenableBuilder<DocumentActiveHeading?>(
                valueListenable: documentActiveHeadingNotifier,
                builder: (context, value, child) =>
                    Text('${value?.blockIndex}'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(documentActiveHeadingNotifier.value, isNull);
  });

  testWidgets(
    'remote content updates keep the editor mounted and do not autosave',
    (tester) async {
      var document = _document();
      var origin = DocumentChangeOrigin.initialRemoteLoad;
      late void Function(NxDocument, DocumentChangeOrigin) update;
      final workspace = FakeNotesWorkspace(documents: <NxDocument>[document]);
      addTearDown(workspace.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentImageAssetServiceProvider.overrideWithValue(null),
            notesWorkspaceProvider.overrideWithValue(workspace),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = (next, nextOrigin) {
                    setState(() {
                      document = next;
                      origin = nextOrigin;
                    });
                  };
                  return DocumentEditorBody(
                    document: document,
                    changeOrigin: origin,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(workspace.openCount, 0);
      final originalEditorState = tester.state(find.byType(AppFlowyEditor));

      update(
        document.copyWith(document: '# Heading\nRemote body'),
        DocumentChangeOrigin.remoteRefresh,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        identical(
          originalEditorState,
          tester.state(find.byType(AppFlowyEditor)),
        ),
        isTrue,
      );
      expect(workspace.openCount, 0);
    },
  );
}

NxDocument _document() {
  return NxDocument(
    id: 1,
    title: 'Reader document',
    modelTypeName: 'Document',
    document: '# Heading\nBody text',
    jsonDocument: const <String, dynamic>{},
    wordCount: 4,
    status: 'Draft',
    topics: const <String>[],
    areaTags: const <String>[],
    tagsBySystem: const <String, List<String>>{},
    pinned: false,
    updatedAt: DateTime.utc(2026),
    updatedLabel: 'now',
    versionNumber: 1,
    excerpt: 'Body text',
    links: const [],
  );
}
