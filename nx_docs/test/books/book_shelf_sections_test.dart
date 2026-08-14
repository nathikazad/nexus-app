import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/books/book_shelf.dart';

void main() {
  test('books are split by reading state and ordered by rank', () {
    final books = <NxDocument>[
      _book(1, 'Second', 'reading', rank: 1),
      _book(2, 'First', 'reading', rank: 0),
      _book(3, 'Waiting', '', rank: 0),
      _book(4, 'Finished', 'read', rank: 0),
    ];

    expect(booksForReadingState(books, 'reading').map((book) => book.id), <int>[
      2,
      1,
    ]);
    expect(booksForReadingState(books, 'to_read').map((book) => book.id), <int>[
      3,
    ]);
    expect(booksForReadingState(books, 'read').map((book) => book.id), <int>[
      4,
    ]);
  });

  testWidgets('library switch changes between to-read and read', (
    tester,
  ) async {
    var selected = BookCollectionView.toRead;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 180,
              child: BookCollectionSwitch(
                value: selected,
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      ),
    );

    expect(selected, BookCollectionView.toRead);
    await tester.tap(
      find.byKey(const ValueKey<String>('book-collection-read')),
    );
    await tester.pump();
    expect(selected, BookCollectionView.read);
  });
}

NxDocument _book(
  int id,
  String title,
  String readingState, {
  required int rank,
}) => NxDocument(
  id: id,
  title: title,
  modelTypeName: 'Book',
  document: '',
  jsonDocument: const <String, dynamic>{},
  wordCount: 0,
  status: 'Draft',
  topics: const <String>[],
  areaTags: const <String>[],
  tagsBySystem: const <String, List<String>>{},
  pinned: false,
  updatedAt: DateTime(2026, 8, 10).subtract(Duration(minutes: id)),
  updatedLabel: '${id}m ago',
  versionNumber: 0,
  excerpt: '',
  links: const [],
  readingState: readingState,
  bookRank: rank,
);
