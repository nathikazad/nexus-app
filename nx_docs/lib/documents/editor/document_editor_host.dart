part of 'document_editor_view.dart';

class DocumentEditorView extends ConsumerStatefulWidget {
  const DocumentEditorView({
    required this.documentId,
    this.contextBar,
    this.onTitleChanged,
    this.onOpenDocumentLink,
    this.canNavigateBack = false,
    this.onNavigateBack,
    this.horizontalPadding = 48,
    this.contentTopPadding = 54,
    this.showDocumentTitle = true,
    this.active = true,
    this.interactionMode = DocumentInteractionMode.edit,
    this.showCompanion = true,
    super.key,
  });

  final int documentId;
  final Widget? contextBar;
  final ValueChanged<String>? onTitleChanged;
  final ValueChanged<int>? onOpenDocumentLink;
  final bool canNavigateBack;
  final VoidCallback? onNavigateBack;
  final double horizontalPadding;
  final double contentTopPadding;
  final bool showDocumentTitle;
  final bool active;
  final DocumentInteractionMode interactionMode;
  final bool showCompanion;

  @override
  ConsumerState<DocumentEditorView> createState() => _DocumentEditorViewState();
}

class _DocumentEditorViewState extends ConsumerState<DocumentEditorView> {
  BrowserArticle? _article;
  Future<BrowserArticle> Function()? _readArticle;

  void _openBrowser(Uri url) => setState(() {
    ref
        .read(documentBrowserSessionProvider(widget.documentId).notifier)
        .open(url);
    _article = null;
    _readArticle = null;
  });

  void _closeBrowser() => setState(() {
    ref
        .read(documentBrowserSessionProvider(widget.documentId).notifier)
        .close();
    _article = null;
    _readArticle = null;
  });

  @override
  void didUpdateWidget(covariant DocumentEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId) {
      _article = null;
      _readArticle = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final browserUrl = ref.watch(
      documentBrowserSessionProvider(widget.documentId),
    );
    if (kDebugMode) {
      debugPrint(
        '[nx_docs editor lifecycle] view-build document=${widget.documentId}',
      );
    }
    final demand = widget.active
        ? ref.watch(documentDemandProvider(widget.documentId))
        : const AsyncValue<void>.data(null);
    final asyncState = ref.watch(
      documentSessionStateProvider(widget.documentId),
    );
    return asyncState.when(
      data: (sessionState) {
        final document = sessionState.document;
        if (document == null) {
          return Center(
            child: Text(
              demand.hasError ||
                      sessionState.phase == DocumentPhase.unavailableOffline
                  ? 'This document has not been downloaded on this device.'
                  : sessionState.phase == DocumentPhase.notFound
                  ? 'Document not found'
                  : 'Opening document…',
            ),
          );
        }
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: DocumentEditorBody(
                scrollStore: ref.watch(documentScrollStoreProvider),
                document: document,
                changeOrigin: sessionState.origin,
                contextBar: widget.contextBar,
                onTitleChanged: widget.onTitleChanged,
                onOpenDocumentLink: widget.onOpenDocumentLink,
                onOpenWebLink: documentBrowserSupported ? _openBrowser : null,
                canNavigateBack: widget.canNavigateBack,
                onNavigateBack: widget.onNavigateBack,
                horizontalPadding: widget.horizontalPadding,
                contentTopPadding: widget.contentTopPadding,
                showDocumentTitle: widget.showDocumentTitle,
                active: widget.active,
                interactionMode: widget.interactionMode,
              ),
            ),
            if (browserUrl != null)
              Positioned.fill(
                child: ref.watch(documentBrowserBuilderProvider)(
                  DocumentBrowser(
                    initialUrl: browserUrl!,
                    sourceTitle: document.title,
                    onReaderReady: (read) => _readArticle = read,
                    onClose: _closeBrowser,
                    onArticleChanged: (article) =>
                        setState(() => _article = article),
                    onOpenDocument: (id) {
                      _closeBrowser();
                      widget.onOpenDocumentLink?.call(id);
                    },
                  ),
                ),
              ),
            if (widget.active && widget.showCompanion)
              Positioned(
                key: ValueKey('document-companion-${document.id}'),
                right: 12,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  left: false,
                  child: NoteCompanion(
                    key: ValueKey('document-companion-${document.id}'),
                    document: document,
                    browserOpen: browserUrl != null,
                    article: _article,
                    readArticle: () async {
                      final read = _readArticle;
                      if (read == null) {
                        throw StateError('Waiting for article text.');
                      }
                      return read();
                    },
                    onAudioBlockChanged: (block) {
                      documentAudioBlockRequestNotifier.value =
                          DocumentAudioBlockRequest(
                            documentId: document.id,
                            blockIndex: block.blockIndex,
                            blockKey: block.blockKey,
                          );
                      _saveAudioScrollAnchor(ref, document, block);
                    },
                  ),
                ),
              ),
          ],
        );
      },
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
