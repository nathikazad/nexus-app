import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/features/editor/document_editor_view.dart';

void main() {
  testWidgets('read-only editor exposes no editing controls', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [documentImageAssetServiceProvider.overrideWithValue(null)],
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
    expect(find.byType(FloatingToolbar), findsNothing);
    expect(find.byKey(const ValueKey<String>('mode-toggle')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('title-display-1')));
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
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
