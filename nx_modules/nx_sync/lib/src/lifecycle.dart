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
    this.checkInterval,
    super.key,
  });

  /// Application-owned synchronization entry point.
  ///
  /// Passing null disables every native lifecycle trigger. This keeps web
  /// applications free of offline behavior without branching in this widget.
  final AppSynchronize? synchronize;
  final Stream<bool>? onlineChanges;
  final Stream<String>? remoteChanges;
  final Duration? checkInterval;
  final Widget child;

  @override
  State<AppSyncLifecycle> createState() => _AppSyncLifecycleState();
}

final class _AppSyncLifecycleState extends State<AppSyncLifecycle>
    with WidgetsBindingObserver {
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<String>? _remoteSubscription;
  AppStateCoordinator? _coordinator;
  Timer? _periodic;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToConnectivity();
    _configureCoordinator();
    _synchronize(SyncReason.appStarted);
  }

  @override
  void didUpdateWidget(AppSyncLifecycle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onlineChanges != widget.onlineChanges) {
      unawaited(_connectivitySubscription?.cancel());
      _listenToConnectivity();
    }
    if (!identical(oldWidget.synchronize, widget.synchronize)) {
      _configureCoordinator();
      _synchronize(SyncReason.appStarted);
    } else if (oldWidget.remoteChanges != widget.remoteChanges ||
        oldWidget.checkInterval != widget.checkInterval) {
      _configureCoordinator();
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
    _periodic?.cancel();
    super.dispose();
  }

  void _listenToConnectivity() {
    _connectivitySubscription = widget.onlineChanges
        ?.where((online) => online)
        .listen((_) => _synchronize(SyncReason.connectivityRestored));
  }

  void _synchronize(SyncReason reason) {
    unawaited(_coordinator?.request(reason));
  }

  void _configureCoordinator() {
    unawaited(_remoteSubscription?.cancel());
    unawaited(_coordinator?.close());
    _periodic?.cancel();
    final synchronize = widget.synchronize;
    _coordinator = synchronize == null
        ? null
        : AppStateCoordinator(synchronize: synchronize);
    _remoteSubscription = widget.remoteChanges?.listen(
      (hint) {
        if (_foreground) _coordinator?.hint(hint);
      },
      onError: (Object _) {
        // Startup/resume and periodic state reads recover missed notifications.
      },
    );
    if (widget.checkInterval case final interval? when synchronize != null) {
      _periodic = Timer.periodic(interval, (_) {
        if (_foreground) _synchronize(SyncReason.timer);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
