import 'dart:async';
import '../data/book/epub_highlights_repository.dart';
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

class EpubRoutePage extends ConsumerStatefulWidget {
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
  ConsumerState<EpubRoutePage> createState() => _EpubRoutePageState();
}

class _EpubRoutePageState extends ConsumerState<EpubRoutePage>
    with WidgetsBindingObserver {
  late EpubHighlightsRepository _highlights;
  StreamSubscription<int>? _subscription;
  Timer? _refreshTimer;
  Map<String, dynamic> _records = {};
  bool _refreshing = false;
  EpubRouteRequest get request => widget.request;
  LocalKey get routeKey => widget.routeKey;
  bool get active => widget.active;
  VoidCallback? get onBack => widget.onBack;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _highlights = ref.read(epubHighlightsRepositoryProvider);
    _subscription = _highlights.changes.listen((id) {
      if (id == request.book.id) unawaited(_readLocal());
    });
    unawaited(_readLocal());
    unawaited(_refresh());
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (active) unawaited(_refresh());
    });
  }

  Future<void> _readLocal() async {
    final records = await _highlights.load(
      request.book.id,
      refreshRemote: false,
    );
    if (mounted) setState(() => _records = records);
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await _highlights.flush();
      if (mounted) await _highlights.load(request.book.id);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _saveHighlight(EpubHighlight highlight, bool deleted) async {
    final id = highlight.id.isEmpty ? newHighlightId() : highlight.id;
    try {
      await _highlights.save(request.book.id, {
        ...highlight.toJson(),
        'id': id,
        'deleted': deleted,
        'sha256': request.book.bookFileHash,
        'updated_at': DateTime.now().toUtc().microsecondsSinceEpoch,
        'revision': newHighlightId(),
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your highlight on this device.'),
          ),
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant EpubRoutePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (active && !oldWidget.active) unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && active) unawaited(_refresh());
    if (state == AppLifecycleState.paused) unawaited(_highlights.flush());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final passage = ref.watch(readerPassageProvider(routeKey));
    final progress = ref.watch(epubProgressRepositoryProvider);
    final book = request.book;
    return EpubReaderPage(
      path: request.path,
      title: book.title,
      textScaleFactor: ref.watch(booksTextScaleProvider),
      savedPosition: request.savedPosition,
      highlights: [
        for (final value in _records.values)
          if (value is Map && value['sha256'] == book.bookFileHash)
            if (EpubHighlight.fromJson(value) case final highlight?) highlight,
      ],
      onHighlightChanged: (highlight, deleted) =>
          unawaited(_saveHighlight(highlight, deleted)),
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
