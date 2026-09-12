import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_documents/nx_documents.dart';
import 'reading_companion.dart';
import 'reading_passage.dart';
export 'reading_passage.dart';
import '../epub/epub_route_page.dart';
import '../epub/retained_epub.dart';

/// Reading capability is declared by a route, never guessed from its URL.
class ReadingRoute extends GoRoute {
  ReadingRoute({
    required super.path,
    required super.builder,
    required this.readingIdentity,
    this.isEpub = false,
  });

  final DocumentIdentity? Function(GoRouterState) readingIdentity;
  final bool isEpub;
}

/// Keep the navigator and companion host mounted as the active route changes.
class ReadingCompanionHost extends ConsumerStatefulWidget {
  const ReadingCompanionHost({
    required this.router,
    required this.enabled,
    required this.child,
    this.sessionKey,
    super.key,
  });
  final GoRouter router;
  final bool enabled;
  final Widget child;
  final Object? sessionKey;

  @override
  ConsumerState<ReadingCompanionHost> createState() =>
      _ReadingCompanionHostState();
}

class _ReadingCompanionHostState extends ConsumerState<ReadingCompanionHost> {
  bool _updateScheduled = false;

  void _routeChanged() {
    // The Router can finish its initial configuration while its descendants
    // are building. Reconcile after that frame, never invalidate an ancestor
    // during Navigator layout. Always read the latest route, not a saved URI.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_updateScheduled) return;
      _updateScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateScheduled = false;
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_routeChanged);
  }

  @override
  void didUpdateWidget(covariant ReadingCompanionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(_routeChanged);
      widget.router.routerDelegate.addListener(_routeChanged);
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_routeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = widget.router;
    final state = router.routerDelegate.currentConfiguration.isEmpty
        ? null
        : router.state;
    final route = state?.topRoute;
    final identity = widget.enabled && route is ReadingRoute
        ? route.readingIdentity(state!)
        : null;
    final passage = identity != null && route is ReadingRoute && route.isEpub
        ? ref.watch(readerPassageProvider(state!.pageKey))
        : null;
    return Overlay.wrap(
      child: ReadingCompanion(
        identity: identity,
        visible: identity != null,
        passage: passage,
        sessionKey: widget.sessionKey,
        child: RetainedEpubHost(
          request:
              identity != null &&
                  route is ReadingRoute &&
                  route.isEpub &&
                  state?.extra is EpubRouteRequest
              ? state!.extra as EpubRouteRequest
              : null,
          routeKey: state?.pageKey,
          bookId: int.tryParse(state?.pathParameters['bookId'] ?? ''),
          keepSession:
              widget.enabled &&
              (identity != null || state?.pathParameters['bookId'] != null),
          account: widget.sessionKey,
          onBack: () => router.pop(),
          child: widget.child,
        ),
      ),
    );
  }
}
