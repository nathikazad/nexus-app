import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../companion/reading_passage.dart';
import '../data/providers.dart';
import '../domain/book/book.dart';
import '../settings/books_preferences.dart';
import 'epub_reader_page.dart';

/// Prepared locally before navigation. No global reader state or callbacks to
/// the summary that opened it. The source EPUB remains unchanged.
class EpubRouteRequest {
  const EpubRouteRequest({
    required this.book,
    required this.path,
    this.savedPosition,
    this.loadedBook,
    this.saveProgress = true,
  });
  final NxBook book;
  final String path;
  final Map<String, dynamic>? savedPosition;
  final EpubBook? loadedBook;
  final bool saveProgress;
}

class EpubRoutePage extends ConsumerWidget {
  const EpubRoutePage({
    required this.request,
    required this.routeKey,
    this.onBack,
    this.active = true,
    super.key,
  });
  final EpubRouteRequest request;
  final LocalKey routeKey;
  final VoidCallback? onBack;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passage = ref.watch(readerPassageProvider(routeKey));
    final progress = ref.watch(epubProgressRepositoryProvider);
    final book = request.book;
    return EpubReaderPage(
      path: request.path,
      title: book.title,
      textScaleFactor: ref.watch(booksTextScaleProvider),
      savedPosition: request.savedPosition,
      navigationRequest: request,
      active: active,
      onBack: onBack,
      loadBook: request.loadedBook == null
          ? loadLocalEpub
          : (_) async => request.loadedBook!,
      onReadingContextChanged: (text) => passage.value =
          'EPUB: ${book.title}\nCurrent reading passage (with nearby context):\n$text',
      onPositionChanged: !request.saveProgress
          ? null
          : (position) => progress.save(book.id, {
              ...position,
              'sha256': book.bookFileHash,
              'saved_at': DateTime.now().toUtc().toIso8601String(),
            }),
    );
  }
}
