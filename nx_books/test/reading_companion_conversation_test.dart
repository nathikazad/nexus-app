import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/companion/reading_companion_controller.dart';
import 'package:nx_books/companion/reading_companion_conversation.dart';

void main() {
  String answer(int lines) =>
      List.generate(lines, (i) => 'Paragraph $i.').join('\n\n');

  for (final size in [
    const Size(400, 300),
    const Size(560, 500),
    const Size(780, 300),
    const Size(560, 550),
    const Size(780, 550),
  ]) {
    testWidgets('reply start stays visible at $size', (tester) async {
      Future<void> render(int lines, {bool busy = true, Size? panel}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox.fromSize(
                  size: panel ?? size,
                  child: ReadingCompanionConversation(
                    messages: [
                      ReadingMessage('user', answer(10)),
                      ReadingMessage('assistant', answer(lines)),
                    ],
                    busy: busy,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await render(2);
      await render(30);
      expect(tester.getTopLeft(find.text('Companion')).dy, closeTo(12, 1));
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final held = scroll.position.pixels;
      await render(45);
      expect(scroll.position.pixels, closeTo(held, 1));
      expect(find.textContaining('Latest'), findsNothing);
      await render(45, busy: false);
      expect(scroll.position.pixels, closeTo(held, 1));
      await render(45, busy: false, panel: const Size(560, 400));
      expect(scroll.position.pixels, closeTo(held, 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('manual scroll pauses following through further chunks', (
    tester,
  ) async {
    Future<void> render(int lines) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: ReadingCompanionConversation(
                messages: [
                  ReadingMessage('user', answer(20)),
                  ReadingMessage('assistant', answer(lines)),
                ],
                busy: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await render(3);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 120));
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final held = position.pixels;
    await render(30);
    expect(position.pixels, closeTo(held, 1));
    expect(find.textContaining('Latest'), findsNothing);
  });

  testWidgets('restored conversation opens at latest', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: ReadingCompanionConversation(
              messages: [
                const ReadingMessage('user', 'Question'),
                ReadingMessage('assistant', answer(40)),
              ],
              busy: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position.extentAfter, closeTo(0, 1));
  });
}
