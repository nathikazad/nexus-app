import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_notes/data/remote/kgql/kgql_book_chapter_repository.dart';
import 'package:nx_notes/domain/book/book_chapter_repository.dart';

final bookChapterRepositoryProvider = Provider<BookChapterRepository>((ref) {
  return KgqlBookChapterRepository(ref.watch(graphqlClientProvider));
});
