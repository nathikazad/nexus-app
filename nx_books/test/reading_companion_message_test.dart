import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/companion/reading_companion_message.dart';

void main() {
  testWidgets('renders reply emphasis and keeps user input literal', (
    tester,
  ) async {
    const text = '**Benefit** and *barrier*';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ReadingCompanionMessage(text: text, fromUser: false),
              ReadingCompanionMessage(text: text, fromUser: true),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text(text), findsOneWidget);
    expect(find.text('Benefit and barrier', findRichText: true), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders inline and display fractions as formatted math', (
    tester,
  ) async {
    const text = r'''Prices move from $10 to $20. The ratio is \(\frac{1}{2}\).

Imagine a price of **$6** *per month* (a $4 discount).

At **$50 per month**, MegaStream's profit per subscriber = $50 – $27 = **$23**.

\[
\text{Unit cost} = \frac{\text{Fixed cost}}{\text{Subscribers}} + 2 = \frac{10{,}000{,}000}{200{,}000} + 2 = \$52 \text{ per month}
\]''';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReadingCompanionMessage(text: text, fromUser: false),
          ),
        ),
      ),
    );

    expect(find.byType(SelectableMath), findsNWidgets(2));
    expect(
      find.textContaining('Prices move from \$10 to \$20', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining(r'$6', findRichText: true), findsOneWidget);
    expect(
      find.textContaining(r'$4 discount', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining(r'$23', findRichText: true), findsOneWidget);
    expect(find.textContaining(r'\frac', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'narrow ${brightness.name} reply supports blocks and streaming',
      (tester) async {
        Future<void> render(String text) => tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 280,
                  child: ReadingCompanionMessage(text: text, fromUser: false),
                ),
              ),
            ),
          ),
        );
        await render('**Partial');
        expect(tester.takeException(), isNull);
        await render(
          '# Summary\n\n**Complete**\n\n- First\n- Second\n\n'
          '> A quotation\n\n```\ncode example\n```\n\n'
          '| Benefit | Explanation |\n| --- | --- |\n'
          '| Scale | Lower costs per subscriber with increasing volume |',
        );
        expect(find.byType(MarkdownBody), findsOneWidget);
        expect(find.byType(Table), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
