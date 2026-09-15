import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:nx_sync/nx_sync.dart';
import 'policy.dart';

/// The persistence module implements this port. Web sessions never instantiate it.
abstract interface class OfflineSyncBackend {
  Future<void> synchronize(SyncReason reason);
}

/// One app's visible-data behavior; scheduling and storage policy stay shared.
final class AppDataDefinition {
  const AppDataDefinition({required this.name, required this.refreshVisible});
  final String name;
  final Future<void> Function() refreshVisible;
}

typedef CheckFreshness = Future<void> Function(Future<void> Function() refresh);

/// Open visible data first. Fill native storage on an independent queue.
final class AppDataSession {
  AppDataSession({
    required this.definition,
    required this.checkFreshness,
    OfflineSyncBackend? offline,
    AppDataPolicy policy = AppDataPolicy.current,
    this.remoteChanges,
    this.onlineChanges,
  }) : _offline = policy.storesOfflineData && offline != null
           ? AppStateCoordinator(synchronize: offline.synchronize)
           : null;

  final AppDataDefinition definition;
  final CheckFreshness checkFreshness;
  final Stream<String>? remoteChanges;
  final Stream<bool>? onlineChanges;
  final AppStateCoordinator? _offline;
  bool _closed = false;
  static const recoveryInterval = Duration(seconds: 30);

  late final Future<void> Function(SyncReason) synchronize = _synchronize;

  Future<void> _synchronize(SyncReason reason) async {
    if (_closed) return;
    try {
      // A committed revision is acknowledged only after visible reads succeed.
      await checkFreshness(definition.refreshVisible);
    } finally {
      // An unavailable server must not prevent local outbox/cache repair.
      // Never await a whole offline library from the foreground lifecycle.
      if (!_closed) unawaited(_offline?.request(reason));
    }
  }

  Future<void> close() async {
    _closed = true;
    await _offline?.close();
  }
}

final class AppDataHost extends StatelessWidget {
  const AppDataHost({required this.session, required this.child, super.key});
  final AppDataSession? session;
  final Widget child;
  @override
  Widget build(BuildContext context) => AppSyncLifecycle(
    synchronize: session?.synchronize,
    remoteChanges: session?.remoteChanges,
    onlineChanges: session?.onlineChanges,
    checkInterval: AppDataSession.recoveryInterval,
    child: child,
  );
}
