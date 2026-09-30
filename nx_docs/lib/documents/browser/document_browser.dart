import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nx_docs/documents/editor/nx_document_link.dart';
import 'package:nx_docs/documents/browser/browser_article.dart';

export 'browser_article.dart';

bool get documentBrowserSupported =>
    !kIsWeb &&
    {
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);

final documentBrowserBuilderProvider =
    Provider<Widget Function(DocumentBrowser)>(
      (_) =>
          (browser) => browser,
    );

/// The owning editor and its companion stay mounted while browsing.
class DocumentBrowser extends StatefulWidget {
  const DocumentBrowser({
    required this.initialUrl,
    required this.sourceTitle,
    required this.onClose,
    required this.onArticleChanged,
    required this.onOpenDocument,
    required this.onReaderReady,
    super.key,
  });

  final Uri initialUrl;
  final String sourceTitle;
  final VoidCallback onClose;
  final ValueChanged<BrowserArticle?> onArticleChanged;
  final ValueChanged<int> onOpenDocument;
  final ValueChanged<Future<BrowserArticle> Function()> onReaderReady;

  @override
  State<DocumentBrowser> createState() => _DocumentBrowserState();
}

class _DocumentBrowserState extends State<DocumentBrowser> {
  InAppWebViewController? _controller;
  late Uri _url = widget.initialUrl;
  late final Future<String> _readability = rootBundle.loadString(
    'assets/article_reader/Readability.js',
  );
  int _navigation = 0;
  bool _back = false;
  bool _forward = false;
  bool _loading = true;
  String? _error;

  void _begin(Uri url) {
    _navigation++;
    setState(() {
      _url = url;
      _loading = true;
      _error = null;
    });
    widget.onArticleChanged(null);
  }

  Future<BrowserArticle> _extract(InAppWebViewController controller) async {
    final navigation = _navigation;
    final url = _url;
    if (_error != null) {
      return BrowserArticle(url: url, title: url.host, text: '', error: _error);
    }
    try {
      final parser = await _readability;
      final extract = await rootBundle.loadString(
        'assets/article_reader/extract.js',
      );
      if (!mounted || navigation != _navigation) {
        throw StateError(
          'The page changed while reading it. Please ask again.',
        );
      }
      // Work on a clone: Readability mutates the DOM it parses.
      final result = await controller.evaluateJavascript(
        source:
            '''
(() => {
$parser
$extract
})()
''',
      );
      if (!mounted || navigation != _navigation) {
        throw StateError(
          'The page changed while reading it. Please ask again.',
        );
      }
      final article = BrowserArticle.fromExtraction(url, result);
      widget.onArticleChanged(article);
      final back = await controller.canGoBack();
      final forward = await controller.canGoForward();
      if (!mounted || navigation != _navigation) {
        throw StateError(
          'The page changed while reading it. Please ask again.',
        );
      }
      setState(() {
        _loading = false;
        _back = back;
        _forward = forward;
      });
      return article;
    } catch (_) {
      if (!mounted || navigation != _navigation) {
        throw StateError(
          'The page changed while reading it. Please ask again.',
        );
      }
      setState(() => _loading = false);
      final article = BrowserArticle(
        url: url,
        title: url.host,
        text: '',
        error:
            'Could not read this page for AI context. Try reloading the page.',
      );
      widget.onArticleChanged(article);
      return article;
    }
  }

  Future<NavigationActionPolicy> _navigate(WebUri? target) async {
    final url = target?.uriValue;
    if (url == null) return NavigationActionPolicy.CANCEL;
    final documentId = nxDocumentIdFromHref(url.toString());
    if (documentId != null) {
      widget.onOpenDocument(documentId);
      return NavigationActionPolicy.CANCEL;
    }
    return isArticleWebUrl(url)
        ? NavigationActionPolicy.ALLOW
        : NavigationActionPolicy.CANCEL;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      if (_back) {
        unawaited(_controller?.goBack());
      } else {
        widget.onClose();
      }
    },
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Return to ${widget.sourceTitle}',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
                IconButton(
                  tooltip: 'Back',
                  onPressed: _back ? () => _controller?.goBack() : null,
                  icon: const Icon(Icons.arrow_back),
                ),
                IconButton(
                  tooltip: 'Forward',
                  onPressed: _forward ? () => _controller?.goForward() : null,
                  icon: const Icon(Icons.arrow_forward),
                ),
                Expanded(
                  child: Text(
                    _url.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Reload page and article context',
                  onPressed: () => _controller?.reload(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri.uri(widget.initialUrl)),
              initialSettings: InAppWebViewSettings(
                useShouldOverrideUrlLoading: true,
                supportMultipleWindows: true,
                javaScriptCanOpenWindowsAutomatically: false,
                allowsInlineMediaPlayback: true,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
                widget.onReaderReady(() => _extract(controller));
              },
              onLoadStart: (_, url) {
                if (url != null) _begin(url.uriValue);
              },
              onLoadStop: (controller, _) async {
                try {
                  await _extract(controller);
                } catch (_) {
                  /* superseded navigation */
                }
              },
              onUpdateVisitedHistory: (controller, url, _) {
                if (url != null && url.uriValue != _url) {
                  _begin(url.uriValue);
                  unawaited(
                    _extract(
                      controller,
                    ).then<void>((_) {}, onError: (Object _) {}),
                  );
                }
              },
              shouldOverrideUrlLoading: (_, action) =>
                  _navigate(action.request.url),
              onCreateWindow: (controller, action) async {
                final target = action.request.url;
                if (await _navigate(target) == NavigationActionPolicy.ALLOW &&
                    mounted) {
                  await controller.loadUrl(urlRequest: URLRequest(url: target));
                }
                return false;
              },
              onReceivedHttpError: (_, request, response) {
                if (request.isForMainFrame != true) return;
                _navigation++;
                setState(() {
                  _loading = false;
                  _error =
                      'This page returned HTTP ${response.statusCode}. Article context is unavailable.';
                });
                widget.onArticleChanged(
                  BrowserArticle(
                    url: _url,
                    title: _url.host,
                    text: '',
                    error: _error,
                  ),
                );
              },
              onReceivedError: (_, request, error) {
                if (request.isForMainFrame != true) return;
                _navigation++;
                setState(() {
                  _loading = false;
                  _error = 'Could not load this page: ${error.description}';
                });
                widget.onArticleChanged(
                  BrowserArticle(
                    url: _url,
                    title: _url.host,
                    text: '',
                    error: _error,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
