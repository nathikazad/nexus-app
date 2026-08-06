import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/features/companion/note_companion.dart';

void main() {
  testWidgets('renders assistant markdown and keeps user input literal', (
    tester,
  ) async {
    const markdown = '**Important**\n\n- First\n- Second';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              NoteCompanionMessageContent(text: markdown, fromUser: false),
              NoteCompanionMessageContent(text: markdown, fromUser: true),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text(markdown), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a wide markdown table without layout overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 330,
            child: NoteCompanionMessageContent(
              text:
                  '| Type | Explanation |\n'
                  '| --- | --- |\n'
                  '| Reputational risk | A deliberately long explanation |',
              fromUser: false,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stays compact until the user opens it', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userIdProvider.overrideWithValue(null),
          sockWsUrlProvider.overrideWithValue(null),
          imageBaseUrlProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          home: Scaffold(body: NoteCompanion(document: _document(42))),
        ),
      ),
    );

    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(find.byIcon(Icons.headphones_rounded), findsOneWidget);
    expect(find.text('Ask about this note'), findsNothing);

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await tester.pump();

    expect(find.text('Ask about this note'), findsOneWidget);
    expect(
      find.text('Sign in to ask questions about this note.'),
      findsOneWidget,
    );
  });

  testWidgets('can be minimized back to the discreet entry point', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userIdProvider.overrideWithValue(null),
          sockWsUrlProvider.overrideWithValue(null),
          imageBaseUrlProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          home: Scaffold(body: NoteCompanion(document: _document(9))),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump();

    expect(find.text('Ask about this note'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
  });
}

NxDocument _document(int id) {
  return NxDocument(
    id: id,
    title: 'Test note',
    modelTypeName: 'Document',
    document: 'Text',
    jsonDocument: const <String, dynamic>{},
    wordCount: 1,
    status: 'Draft',
    topics: const <String>[],
    areaTags: const <String>[],
    tagsBySystem: const <String, List<String>>{},
    pinned: false,
    updatedAt: DateTime(2026),
    updatedLabel: 'now',
    versionNumber: 0,
    excerpt: 'Text',
    links: const [],
  );
}
