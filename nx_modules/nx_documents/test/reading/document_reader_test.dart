import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_documents/nx_documents.dart';

void main() {
  testWidgets('reader highlights text and emits only document content', (
    tester,
  ) async {
    DocumentContent? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 700)),
          child: Scaffold(
            body: DocumentReader(
              content: _content(),
              onChanged: (content) async => saved = content,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
    expect(editor.editable, isFalse);
    expect(editor.disableKeyboardService, isTrue);
    expect(editor.editorStyle.mobileDragHandleBallSize, const Size(8, 8));

    editor.editorState.selection = Selection.single(
      path: const <int>[1],
      startOffset: 0,
      endOffset: 4,
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey<String>('reader-highlight-clear')),
      findsOneWidget,
    );
    for (final color in <String>[
      nxReaderHighlightYellow,
      nxReaderHighlightGreen,
      nxReaderHighlightPink,
    ]) {
      expect(
        find.byKey(ValueKey<String>('reader-highlight-$color')),
        findsOneWidget,
      );
    }

    await tester.tap(
      find.byKey(
        const ValueKey<String>('reader-highlight-$nxReaderHighlightYellow'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(saved, isNotNull);
    expect(saved!.identity.modelType, 'Book');
    expect(saved!.plainText, _content().plainText);
    expect(_bodyHighlight(saved!), nxReaderHighlightYellow);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('host loads a composite Book identity', (tester) async {
    final repository = _MemoryRepository(_content());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentReaderHost(
            identity: const DocumentIdentity(id: 7, modelType: 'Book'),
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.loadedIdentity, _content().identity);
    expect(find.byType(AppFlowyEditor), findsOneWidget);
  });

  testWidgets('host reports a missing document instead of loading forever', (
    tester,
  ) async {
    final repository = _MemoryRepository(null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentReaderHost(
            identity: const DocumentIdentity(id: 404, modelType: 'Book'),
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No notes were found for this document.'), findsOneWidget);
  });

  testWidgets('reader paints imported table content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentReader(
            content: _tableContent(),
            onChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('nx-read-table')), findsOneWidget);
    expect(find.text('Signal'), findsOneWidget);
    expect(find.text('Substance'), findsOneWidget);
  });

  testWidgets('a single tap opens a link through the reader callback', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 700)),
          child: Scaffold(
            body: DocumentReader(
              content: _linkContent(),
              onChanged: (_) async {},
              onOpenLink: (href) async {
                opened = href;
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AppFlowyRichText));
    await tester.pump();

    expect(opened, 'https://example.com');
  });

  testWidgets('a long press on a link selects without opening it', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 700)),
          child: Scaffold(
            body: DocumentReader(
              content: _linkContent(),
              onChanged: (_) async {},
              onOpenLink: (href) async {
                opened = href;
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
    await tester.longPress(find.byType(AppFlowyRichText));
    await tester.pump();

    expect(opened, isNull);
    expect(editor.editorState.selection, isNotNull);
    expect(editor.editorState.selection!.isCollapsed, isFalse);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });
}

DocumentContent _content() {
  return DocumentContent(
    identity: const DocumentIdentity(id: 7, modelType: 'Book'),
    title: 'Book notes',
    plainText: '# Heading\nBody text',
    jsonDocument: const <String, dynamic>{},
    updatedAt: DateTime.utc(2026),
  );
}

DocumentContent _tableContent() {
  return DocumentContent(
    identity: const DocumentIdentity(id: 8, modelType: 'Book'),
    title: 'Table notes',
    plainText: 'Signal Substance',
    jsonDocument: const <String, dynamic>{
      'format': 'appflowy_document',
      'document': <String, dynamic>{
        'type': 'page',
        'children': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'table',
            'data': <String, dynamic>{'colsLen': 2, 'rowsLen': 1},
            'children': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'table/cell',
                'data': <String, dynamic>{'colPosition': 0, 'rowPosition': 0},
                'children': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 'paragraph',
                    'data': <String, dynamic>{
                      'delta': <Map<String, dynamic>>[
                        <String, dynamic>{'insert': 'Signal'},
                      ],
                    },
                  },
                ],
              },
              <String, dynamic>{
                'type': 'table/cell',
                'data': <String, dynamic>{'colPosition': 1, 'rowPosition': 0},
                'children': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 'paragraph',
                    'data': <String, dynamic>{
                      'delta': <Map<String, dynamic>>[
                        <String, dynamic>{'insert': 'Substance'},
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
    updatedAt: DateTime.utc(2026),
  );
}

DocumentContent _linkContent() {
  return DocumentContent(
    identity: const DocumentIdentity(id: 9, modelType: 'Book'),
    title: 'Linked notes',
    plainText: 'Nexus link',
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
                  'insert': 'Nexus link',
                  'attributes': <String, dynamic>{
                    'href': 'https://example.com',
                  },
                },
              ],
            },
          },
        ],
      },
    },
    updatedAt: DateTime.utc(2026),
  );
}

String? _bodyHighlight(DocumentContent content) {
  final document = content.jsonDocument['document'] as Map?;
  final children = document?['children'] as List?;
  final body = children?[1] as Map?;
  final data = body?['data'] as Map?;
  final delta = data?['delta'] as List?;
  final operation = delta?.first as Map?;
  final attributes = operation?['attributes'] as Map?;
  return attributes?[AppFlowyRichTextKeys.backgroundColor] as String?;
}

class _MemoryRepository implements DocumentContentRepository {
  _MemoryRepository(this.content);

  DocumentContent? content;
  DocumentIdentity? loadedIdentity;

  @override
  Future<DocumentContent?> load(DocumentIdentity identity) async {
    loadedIdentity = identity;
    return content;
  }

  @override
  Future<DocumentContent> save(DocumentContent next) async {
    content = next;
    return next;
  }
}
