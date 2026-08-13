import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/application/document_session.dart';
import 'package:nx_docs/application/fake/fake_notes_workspace.dart';
import 'package:nx_docs/composition/notes_composition.dart';
import 'package:nx_docs/data/providers.dart';
import 'package:nx_docs/domain/document/document.dart';
import 'package:nx_docs/features/editor/document_editor_view.dart';
import 'package:nx_docs/features/editor/document_text_scale.dart';
import 'package:nx_docs/features/editor/nx_appflowy_blocks.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('read mode replaces only the table presentation builder', () {
    expect(
      nxBlockComponentBuilders()[TableBlockKeys.type],
      isA<TableBlockComponentBuilder>(),
    );
    expect(
      nxBlockComponentBuilders(useReadTable: true)[TableBlockKeys.type],
      isA<NxReadTableBlockComponentBuilder>(),
    );
  });

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

  for (final width in <double>[390, 1200]) {
    testWidgets('reader renders stored table cells at ${width.toInt()}px', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentImageAssetServiceProvider.overrideWithValue(null),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                height: 700,
                child: DocumentEditorBody(
                  document: _tableDocument(),
                  readOnly: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('nx-read-table')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey<String>('nx-read-table')))
            .height,
        lessThan(328),
      );
      expect(find.text('More for personal use'), findsOneWidget);
      expect(find.text('More for showing off'), findsOneWidget);
      expect(find.text('Gasoline, insurance'), findsOneWidget);
      expect(find.text('Restaurants, living-room furniture'), findsOneWidget);
    });
  }

  testWidgets('editable desktop document also renders stored table cells', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [documentImageAssetServiceProvider.overrideWithValue(null)],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)),
            child: Scaffold(
              body: DocumentEditorBody(document: _tableDocument()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
    expect(editor.editable, isTrue);
    expect(find.byKey(const ValueKey<String>('nx-read-table')), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('nx-read-table')))
          .height,
      lessThan(328),
    );
    expect(find.text('More for personal use'), findsOneWidget);
    expect(find.text('Restaurants, living-room furniture'), findsOneWidget);
  });

  testWidgets('narrow long document shows a subtle scroll position dot', (
    tester,
  ) async {
    final longDocument = _document().copyWith(
      document: List<String>.generate(
        80,
        (index) => 'Paragraph $index with enough text to form the document.',
      ).join('\n\n'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [documentImageAssetServiceProvider.overrideWithValue(null)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 700,
              child: DocumentEditorBody(document: longDocument, readOnly: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('document-scroll-position-dot')),
      findsOneWidget,
    );
  });

  testWidgets('saved text scale applies only to document content', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      DocumentTextScaleNotifier.preferenceKey: 1.4,
    });

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
    await tester.pumpAndSettle();

    final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
    expect(editor.editorStyle.textScaleFactor, 1.4);
    final readerTextStyle = editor.editorStyle.textStyleConfiguration.text;
    expect(readerTextStyle.fontFamily, isNull);
    expect(readerTextStyle.fontSize, 18);
    expect(readerTextStyle.height, 1.6);
    expect(editor.editorStyle.textStyleConfiguration.lineHeight, 1.6);
    final titleContext = tester.element(
      find.byKey(const ValueKey<String>('title-display-1')),
    );
    expect(MediaQuery.textScalerOf(titleContext).scale(1), 1.0);
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

NxDocument _tableDocument() {
  return _document().copyWith(
    document: 'Most goods mix functional and signaling value',
    jsonDocument: const <String, dynamic>{
      'format': 'appflowy_document',
      'document': <String, dynamic>{
        'type': 'page',
        'children': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'paragraph',
            'data': <String, dynamic>{
              'delta': <Map<String, dynamic>>[
                <String, dynamic>{
                  'insert': 'Most goods mix functional and signaling value:',
                },
              ],
            },
          },
          <String, dynamic>{
            'type': 'table',
            'data': <String, dynamic>{
              'colsLen': 2,
              'rowsLen': 2,
              'colsHeight': 328,
              'colDefaultWidth': 160,
              'rowDefaultHeight': 40,
            },
            'children': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'table/cell',
                'data': <String, dynamic>{
                  'colPosition': 0,
                  'rowPosition': 0,
                  'width': 160,
                  'height': 60,
                },
                'children': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 'paragraph',
                    'data': <String, dynamic>{
                      'delta': <Map<String, dynamic>>[
                        <String, dynamic>{'insert': 'More for personal use'},
                      ],
                    },
                  },
                ],
              },
              <String, dynamic>{
                'type': 'table/cell',
                'data': <String, dynamic>{
                  'colPosition': 1,
                  'rowPosition': 0,
                  'width': 160,
                  'height': 60,
                },
                'children': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 'paragraph',
                    'data': <String, dynamic>{
                      'delta': <Map<String, dynamic>>[
                        <String, dynamic>{'insert': 'More for showing off'},
                      ],
                    },
                  },
                ],
              },
              <String, dynamic>{
                'type': 'table/cell',
                'data': <String, dynamic>{
                  'colPosition': 0,
                  'rowPosition': 1,
                  'width': 160,
                  'height': 86,
                },
                'children': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 'paragraph',
                    'data': <String, dynamic>{
                      'delta': <Map<String, dynamic>>[
                        <String, dynamic>{'insert': 'Gasoline, insurance'},
                      ],
                    },
                  },
                ],
              },
              <String, dynamic>{
                'type': 'table/cell',
                'data': <String, dynamic>{
                  'colPosition': 1,
                  'rowPosition': 1,
                  'width': 160,
                  'height': 86,
                },
                'children': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 'paragraph',
                    'data': <String, dynamic>{
                      'delta': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'insert': 'Restaurants, living-room furniture',
                        },
                      ],
                    },
                  },
                ],
              },
            ],
          },
        ],
      },
    },
  );
}
