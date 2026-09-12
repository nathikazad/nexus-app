import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/book/book.dart';
import 'epub_route_page.dart';

/// One parsed document, shared by source resolution and the mounted reader.
/// Never retain a library of parsed books on a memory-constrained device.
class ActiveEpubCache {
  EpubRouteRequest? current;
  EpubRouteRequest? forBook(NxBook book) {
    final value = current;
    return value?.book.id == book.id &&
            value?.book.bookFileHash == book.bookFileHash
        ? value
        : null;
  }

  void clear() => current = null;
}

final activeEpubCacheProvider = Provider<ActiveEpubCache>(
  (ref) => ActiveEpubCache(),
);

/// The router still owns visibility and back navigation. This single slot owns
/// renderer lifetime, keeping its layout/controller mounted behind summaries.
class RetainedEpubHost extends ConsumerStatefulWidget {
  const RetainedEpubHost({
    required this.child,
    required this.request,
    required this.routeKey,
    required this.bookId,
    required this.keepSession,
    required this.onBack,
    required this.account,
    super.key,
  });
  final Widget child;
  final EpubRouteRequest? request;
  final LocalKey? routeKey;
  final int? bookId;
  final bool keepSession;
  final VoidCallback onBack;
  final Object? account;
  @override
  ConsumerState<RetainedEpubHost> createState() => _RetainedEpubHostState();
}

class _RetainedEpubHostState extends ConsumerState<RetainedEpubHost>
    with WidgetsBindingObserver {
  EpubRouteRequest? _retained;
  LocalKey? _routeKey;

  @override
  void didUpdateWidget(covariant RetainedEpubHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account ||
        !widget.keepSession ||
        (widget.bookId != null && widget.bookId != _retained?.book.id)) {
      _retained = null;
      _routeKey = null;
      ref.read(activeEpubCacheProvider).clear();
    }
    _accept();
  }

  void _accept() {
    if (widget.request case final request?) {
      _retained = request;
      _routeKey = widget.routeKey;
      ref.read(activeEpubCacheProvider).current = request;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _accept();
  }

  @override
  void didHaveMemoryPressure() {
    if (widget.request != null) return;
    ref.read(activeEpubCacheProvider).clear();
    setState(() {
      _retained = null;
      _routeKey = null;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (_retained case final request?)
        Offstage(
          offstage: widget.request == null,
          child: TickerMode(
            enabled: widget.request != null,
            child: EpubRoutePage(
              key: ValueKey((request.book.id, request.book.bookFileHash)),
              request: request,
              routeKey: _routeKey!,
              onBack: widget.onBack,
              active: widget.request != null,
            ),
          ),
        ),
    ],
  );
}
