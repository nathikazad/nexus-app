import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_documents/nx_documents.dart';
import 'package:url_launcher/url_launcher.dart';

final bookNotesRepositoryProvider = Provider<DocumentContentRepository>((ref) {
  return KgqlDocumentContentRepository(
    client: ref.watch(graphqlClientProvider),
    auditSourceKind: 'nx_books',
  );
});

final bookNotesImageBaseProvider = Provider<Uri?>((ref) {
  final user = ref.watch(authProvider).value;
  return user == null ? null : Uri.parse(resolve(user.preset).imageHttp);
});

String bookNotesPath(int bookId) => '/books/$bookId/notes';
String bookDetailsPath(int bookId) => '/books/$bookId/details';
String documentNotesPath(int documentId) => '/documents/$documentId/notes';

class BookNotesPage extends ConsumerWidget {
  const BookNotesPage({required this.bookId, super.key});

  final int bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _NotesPage(
      identity: DocumentIdentity(id: bookId, modelType: 'Book'),
      title: 'Book Notes',
      detailsPath: bookDetailsPath(bookId),
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
  });

  final DocumentIdentity identity;
  final String title;
  final String? detailsPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageBase = ref.watch(bookNotesImageBaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
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
