import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_docs/books/data/kgql/kgql_book_chapter_repository.dart';
import 'package:nx_docs/books/book_chapter_repository.dart';

final bookChapterRepositoryProvider = Provider<BookChapterRepository>((ref) {
  return KgqlBookChapterRepository(ref.watch(graphqlClientProvider));
});
