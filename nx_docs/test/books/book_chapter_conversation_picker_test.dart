import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/companion/conversation_reference.dart';
import 'package:nx_docs/books/book_chapter.dart';
import 'package:nx_docs/books/book_chapter_repository.dart';
import 'package:nx_docs/books/book_conversation_picker.dart';

void main() {
  testWidgets('chooses chapters before creating conversation references', (
    tester,
  ) async {
    List<ConversationReference>? startedWith;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 380,
            height: 600,
            child: BookChapterConversationPicker(
              bookId: 7,
              repository: _FakeBookChapterRepository(),
              onStart: (references) => startedWith = references,
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose chapters'), findsOneWidget);
    expect(find.text('Chapter one'), findsOneWidget);
    expect(find.text('Chapter two'), findsOneWidget);
    expect(find.text('0 selected'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('book-chapter-2')));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('book-chapter-start-conversation')),
    );
    await tester.pump();
    await tester.pump();

    expect(startedWith, isNotNull);
    expect(startedWith!.single.id, 'book-chapter:2');
    expect(startedWith!.single.content, 'Second body');
  });
}

final class _FakeBookChapterRepository implements BookChapterRepository {
  @override
  Future<List<BookChapterSummary>> listChapters(int bookId) async => const [
    BookChapterSummary(
      id: 1,
      title: 'Chapter one',
      chapterNumber: 1,
      description: 'First summary',
    ),
    BookChapterSummary(
      id: 2,
      title: 'Chapter two',
      chapterNumber: 2,
      description: 'Second summary',
    ),
  ];

  @override
  Future<List<BookChapter>> loadSelectedChapters({
    required int bookId,
    required Set<int> chapterIds,
  }) async => [
    if (chapterIds.contains(1))
      const BookChapter(
        id: 1,
        title: 'Chapter one',
        chapterNumber: 1,
        content: 'First body',
      ),
    if (chapterIds.contains(2))
      const BookChapter(
        id: 2,
        title: 'Chapter two',
        chapterNumber: 2,
        content: 'Second body',
      ),
  ];
}
