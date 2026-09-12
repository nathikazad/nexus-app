import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_books/data/providers.dart';
import 'package:nx_books/domain/book/book.dart';
import 'package:nx_books/settings/books_preferences.dart';
import 'package:nx_books/companion/reading_companion.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_documents/nx_documents.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:async';
import 'package:nx_books/epub/epub_reader_page.dart';
import 'package:nx_books/companion/epub_companion_context.dart';
import 'package:nx_books/data/offline/reading_position_store.dart';

final bookNotesRepositoryProvider = Provider<DocumentContentRepository>((ref) {
  return ref.watch(bookDocumentRepositoryProvider);
});
final bookNotesPositionStoreProvider = Provider<ReadingPositionStore?>((ref) {
  final userId = ref.watch(authProvider).value?.userId;
  return userId == null ? null : ReadingPositionStore('nexus-primary:$userId');
});

final bookNotesImageBaseProvider = Provider<Uri?>((ref) {
  final user = ref.watch(authProvider).value;
  return user == null ? null : Uri.parse(resolve(user.preset).imageHttp);
});

final bookFileOpenerProvider = Provider<Future<void> Function(String)>((ref) {
  return (path) async {
    final result = await OpenFilex.open(
      path,
      type: path.toLowerCase().endsWith('.pdf')
          ? 'application/pdf'
          : 'application/epub+zip',
    );
    if (result.type != ResultType.done) {
      throw StateError(result.message);
    }
  };
});

String bookNotesPath(int bookId) => '/books/$bookId/notes';
String bookDetailsPath(int bookId) => '/books/$bookId/details';
String documentNotesPath(int documentId) => '/documents/$documentId/notes';

class BookNotesPage extends ConsumerWidget {
  const BookNotesPage({required this.bookId, super.key});

  final int bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    NxBook? book;
    for (final candidate
        in ref.watch(booksProvider).value ?? const <NxBook>[]) {
      if (candidate.id == bookId) {
        book = candidate;
        break;
      }
    }
    return _NotesPage(
      identity: DocumentIdentity(id: bookId, modelType: 'Book'),
      title: 'Book Notes',
      detailsPath: bookDetailsPath(bookId),
      book: book,
    );
  }
}

class DocumentNotesPage extends ConsumerWidget {
  const DocumentNotesPage({required this.documentId, super.key});

  final int documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _NotesPage(
      identity: DocumentIdentity(id: documentId, modelType: 'Document'),
      title: 'Document',
    );
  }
}

class _NotesPage extends ConsumerWidget {
  const _NotesPage({
    required this.identity,
    required this.title,
    this.detailsPath,
    this.book,
  });

  final DocumentIdentity identity;
  final String title;
  final String? detailsPath;
  final NxBook? book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageBase = ref.watch(bookNotesImageBaseProvider);
    final textScale = ref.watch(booksTextScaleProvider);
    final positions = ref.watch(bookNotesPositionStoreProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (book case final attached? when attached.bookLink.isNotEmpty)
            IconButton(
              key: const ValueKey<String>('open-book-file-button'),
              tooltip: 'Open book',
              onPressed: () => _openBookFile(context, ref, attached),
              icon: const Icon(Icons.menu_book_outlined),
            ),
          if (detailsPath case final path?)
            IconButton(
              key: const ValueKey<String>('book-details-button'),
              tooltip: 'Book details',
              onPressed: () => context.push(path),
              icon: const Icon(Icons.settings_outlined),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: DocumentReaderHost(
                identity: identity,
                repository: ref.watch(bookNotesRepositoryProvider),
                loadPosition: positions == null
                    ? null
                    : () => positions.load(identity),
                onPositionChanged: positions == null
                    ? null
                    : (position) {
                        unawaited(
                          positions
                              .save(identity, position)
                              .catchError((Object _) {}),
                        );
                      },
                textScaleFactor: textScale,
                onUseSelection: (text) =>
                    ref.read(readingSelectionProvider).value =
                        ReadingSelectionRequest(identity, text),
                onOpenLink: (href) => _openNotesLink(context, href),
                imageUrlResolver: imageBase == null
                    ? null
                    : (url) => _resolveImageUrl(imageBase, url),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openBookFile(
  BuildContext context,
  WidgetRef ref,
  NxBook book,
) async {
  try {
    final cache = ref.read(bookFileCacheProvider);
    if (cache == null) throw StateError('Book files are unavailable here');
    final path = await cache.openPath(book);
    if (path.toLowerCase().endsWith('.epub')) {
      final progress = ref.read(epubProgressRepositoryProvider);
      final saved = await progress.load(book.id);
      final matching = saved?['sha256'] == book.bookFileHash ? saved : null;
      if (context.mounted) {
        final excerpt = ref.read(epubCompanionContextProvider);
        excerpt.value = EpubCompanionContext(book.id, '');
        try {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Consumer(
                builder: (context, ref, _) => EpubReaderPage(
                  textScaleFactor: ref.watch(booksTextScaleProvider),
                  onReadingContextChanged: (text) =>
                      excerpt.value = EpubCompanionContext(
                        book.id,
                        'EPUB: ${book.title}\nCurrent reading passage (with nearby context):\n$text',
                      ),
                  path: path,
                  title: book.title,
                  savedPosition: matching,
                  onPositionChanged: (position) => progress.save(book.id, {
                    ...position,
                    'sha256': book.bookFileHash,
                    'saved_at': DateTime.now().toUtc().toIso8601String(),
                  }),
                ),
              ),
            ),
          );
        } finally {
          excerpt.value = null;
        }
      }
      return;
    }
    await ref.read(bookFileOpenerProvider)(path);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open this book. Connect to Nexus and sync it first.',
          ),
        ),
      );
    }
  }
}

Future<bool> _openNotesLink(BuildContext context, String href) async {
  final internalPath = notesPathForHref(href);
  if (internalPath != null) {
    context.push(internalPath);
    return true;
  }

  final parsed = Uri.tryParse(href.trim());
  if (parsed == null) return false;
  final uri = parsed.hasScheme ? parsed : Uri.parse('https://${href.trim()}');
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

String? notesPathForHref(String href) {
  final identity = documentIdentityFromKgqlHref(href);
  final modelType = identity?.modelType.toLowerCase();
  return identity != null && (modelType == 'document' || modelType == 'essay')
      ? documentNotesPath(identity.id)
      : null;
}

String _resolveImageUrl(Uri imageBase, String storedUrl) {
  final uri = Uri.tryParse(storedUrl);
  if (uri == null || uri.hasScheme) return storedUrl;
  return imageBase.resolveUri(uri).toString();
}
