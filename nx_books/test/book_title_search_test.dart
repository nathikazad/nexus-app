import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/domain/book/book.dart';
import 'package:nx_books/features/books/book_title_search.dart';

NxBook book(int id, String title) => NxBook(
  id: id,
  title: title,
  description: '',
  author: '',
  link: '',
  tags: [],
  readingState: BookReadingState.reading,
  rank: 0,
  wordCount: 0,
  updatedAt: DateTime(2026),
  updatedLabel: '',
);

void main() {
  testWidgets(
    'search expands left, filters titles, opens selection and dismisses',
    (tester) async {
      int? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                BookTitleSearch(
                  books: [
                    book(1, '7 Powers'),
                    book(2, 'Difficult Conversations'),
                  ],
                  onOpen: (book) => opened = book.id,
                ),
              ],
            ),
          ),
        ),
      );
      final buttonRight = tester
          .getRect(find.byType(CompositedTransformTarget))
          .right;
      await tester.tap(find.byTooltip('Search books'));
      await tester.pumpAndSettle();
      expect(find.text('7 Powers'), findsOneWidget);
      final decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
      expect(decoration.focusedBorder, InputBorder.none);
      expect(decoration.enabledBorder, InputBorder.none);
      expect(find.text('Difficult Conversations'), findsOneWidget);
      expect(
        tester.getRect(find.byType(TextField)).right,
        closeTo(buttonRight, 1),
      );
      await tester.enterText(find.byType(TextField), 'POWER');
      await tester.pumpAndSettle();
      expect(find.text('Difficult Conversations'), findsNothing);
      await tester.tap(find.text('7 Powers'));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byTooltip('Search books'));
      await tester.pumpAndSettle();
      expect(find.text('Difficult Conversations'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'unmatched');
      await tester.pump();
      expect(find.text('No matching titles'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
