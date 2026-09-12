import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/features/books/book_opening_indicator.dart';

void main() {
  testWidgets('opening indicator blocks duplicate taps and dismisses safely', (
    tester,
  ) async {
    late VoidCallback dismiss;
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                opens++;
                dismiss = showBookOpeningIndicator(context);
              },
              child: const Text('Open book'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open book'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.text('Open book')));
    expect(opens, 1);
    dismiss();
    dismiss();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Open book'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
