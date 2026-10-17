import 'dart:async';

import 'package:flutter/material.dart';

import 'reason.dart';
import 'coordinator.dart';

typedef AppSynchronize = Future<void> Function(SyncReason reason);

final class AppSyncLifecycle extends StatefulWidget {
  const AppSyncLifecycle({
    required this.synchronize,
    required this.child,
    this.onlineChanges,
    this.remoteChanges,
    this.resumeInterval = const Duration(minutes: 5),
    this.now,
    super.key,
  });

  /// Application-owned synchronization entry point.
  ///
  /// Passing null disables every native lifecycle trigger. This keeps web
  /// applications free of offline behavior without branching in this widget.
  final AppSynchronize? synchronize;
  final Stream<bool>? onlineChanges;
  final Stream<String>? remoteChanges;

  /// Resume checks are skipped until this long after a successful sync check.
  final Duration resumeInterval;
  final DateTime Function()? now;
  final Widget child;

  @override
  State<AppSyncLifecycle> createState() => _AppSyncLifecycleState();
}

final class _AppSyncLifecycleState extends State<AppSyncLifecycle>
    with WidgetsBindingObserver {
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<String>? _remoteSubscription;
  AppStateCoordinator? _coordinator;
  DateTime? _lastSuccessfulSync;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToConnectivity();
    _configureCoordinator();
    _listenToRemoteChanges();
    _synchronize(SyncReason.appStarted);
  }

  @override
  void didUpdateWidget(AppSyncLifecycle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onlineChanges != widget.onlineChanges) {
      unawaited(_connectivitySubscription?.cancel());
      _listenToConnectivity();
    }
    if (oldWidget.remoteChanges != widget.remoteChanges) {
      unawaited(_remoteSubscription?.cancel());
      _listenToRemoteChanges();
    }
    if (!identical(oldWidget.synchronize, widget.synchronize)) {
      _configureCoordinator();
      _synchronize(SyncReason.appStarted);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Desktop windows can remain visible while another window has focus.
    // Inactive is not hidden; keep those visible libraries synchronized.
    _foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (state == AppLifecycleState.resumed) {
      _synchronize(SyncReason.appResumed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_remoteSubscription?.cancel());
    unawaited(_coordinator?.close());
    super.dispose();
  }

  void _listenToConnectivity() {
    _connectivitySubscription = widget.onlineChanges
        ?.where((online) => online)
        .listen((_) => _synchronize(SyncReason.connectivityRestored));
  }

  void _synchronize(SyncReason reason) {
    final last = _lastSuccessfulSync;
    if (reason == SyncReason.appResumed &&
        last != null &&
        (widget.now?.call() ?? DateTime.now()).difference(last) <=
            widget.resumeInterval) {
      return;
    }
    unawaited(_coordinator?.request(reason));
  }

  void _configureCoordinator() {
    unawaited(_coordinator?.close());
    final synchronize = widget.synchronize;
    _lastSuccessfulSync = null;
    _coordinator = synchronize == null
        ? null
        : AppStateCoordinator(
            synchronize: (reason) async {
              await synchronize(reason);
              if (mounted && identical(widget.synchronize, synchronize)) {
                _lastSuccessfulSync = widget.now?.call() ?? DateTime.now();
              }
            },
          );
  }

  void _listenToRemoteChanges() {
    // Keep this subscription when callbacks change. A
    // single-subscription stream cannot be listened to again after cancellation.
    _remoteSubscription = widget.remoteChanges?.listen(
      (hint) {
        if (_foreground) _coordinator?.hint(hint);
      },
      onError: (Object _) {
        // Startup and stale resume checks recover missed notifications.
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
