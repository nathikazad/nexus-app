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

  testWidgets('offers compact note playback speed choices', (tester) async {
    double? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: NotePlaybackSpeedButton(
              speed: 1,
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    expect(find.text('1×'), findsOneWidget);

    await tester.tap(find.text('1×'));
    await tester.pumpAndSettle();

    expect(find.text('0.75×'), findsOneWidget);
    expect(find.text('1.25×'), findsOneWidget);
    expect(find.text('1.5×'), findsOneWidget);
    expect(find.text('2×'), findsOneWidget);
    expect(tester.widget<Text>(find.text('1.5×')).style?.color, Colors.white);

    final buttonRect = tester.getRect(
      find.byKey(const ValueKey<String>('note-playback-speed-button')),
    );
    final menuItemRect = tester.getRect(
      find.byKey(const ValueKey<String>('note-playback-speed-1.5')),
    );
    expect(menuItemRect.center.dx, lessThan(buttonRect.center.dx));
    expect(menuItemRect.center.dy, lessThan(buttonRect.center.dy));

    await tester.tap(
      find.byKey(const ValueKey<String>('note-playback-speed-1.5')),
    );
    await tester.pumpAndSettle();

    expect(selected, 1.5);
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
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: NoteCompanion(document: _document(42)),
                ),
              ],
            ),
          ),
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
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('note-companion-chat-panel')),
          )
          .height,
      greaterThan(380),
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('note-companion-chat-panel')),
          )
          .dy,
      greaterThanOrEqualTo(20),
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

  testWidgets('embedded desktop chat is text-only without floating actions', (
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
          home: Scaffold(
            body: SizedBox(
              width: 288,
              height: 600,
              child: NoteCompanion(
                document: _document(10),
                embeddedChat: true,
                voiceEnabled: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('note-companion-embedded-chat')),
      findsOneWidget,
    );
    expect(
      find.text('Sign in to ask questions about this note.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
    expect(find.byIcon(Icons.headphones_rounded), findsNothing);
    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    expect(tester.takeException(), isNull);
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
