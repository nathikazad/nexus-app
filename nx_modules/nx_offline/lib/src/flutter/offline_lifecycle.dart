import 'dart:async';

import 'package:flutter/material.dart';

import '../core/sync_models.dart';
import '../sync/sync_ports.dart';

typedef OfflineSynchronize = Future<void> Function(SyncReason reason);

final class OfflineLifecycle extends StatefulWidget {
  const OfflineLifecycle({
    required this.synchronize,
    required this.child,
    this.onlineChanges,
    super.key,
  });

  /// Application-owned synchronization entry point.
  ///
  /// Passing null disables every native lifecycle trigger. This keeps web
  /// applications free of offline behavior without branching in this widget.
  final OfflineSynchronize? synchronize;
  final Stream<bool>? onlineChanges;
  final Widget child;

  @override
  State<OfflineLifecycle> createState() => _OfflineLifecycleState();
}

final class _OfflineLifecycleState extends State<OfflineLifecycle>
    with WidgetsBindingObserver {
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToConnectivity();
    _synchronize(SyncReason.appStarted);
  }

  @override
  void didUpdateWidget(OfflineLifecycle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onlineChanges != widget.onlineChanges) {
      unawaited(_connectivitySubscription?.cancel());
      _listenToConnectivity();
    }
    if (!identical(oldWidget.synchronize, widget.synchronize)) {
      _synchronize(SyncReason.appStarted);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _synchronize(SyncReason.appResumed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_connectivitySubscription?.cancel());
    super.dispose();
  }

  void _listenToConnectivity() {
    _connectivitySubscription = widget.onlineChanges
        ?.where((online) => online)
        .listen((_) => _synchronize(SyncReason.connectivityRestored));
  }

  void _synchronize(SyncReason reason) {
    final synchronize = widget.synchronize;
    if (synchronize != null) {
      unawaited(synchronize(reason).catchError((Object _) {}));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

final class SyncStatusView extends StatelessWidget {
  const SyncStatusView({required this.source, this.textStyle, super.key});

  final SyncStatusSource source;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: source.statusChanges,
      initialData: source.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? source.status;
        return Semantics(
          label: 'Synchronization status',
          child: Text(_label(status), style: textStyle),
        );
      },
    );
  }

  String _label(SyncStatus status) {
    return switch (status.activity) {
      SyncActivity.idle =>
        status.lastSyncedAt == null ? 'Saved locally' : 'Synced',
      SyncActivity.syncing => 'Syncing',
      SyncActivity.retryWaiting =>
        'Sync pending - ${status.pendingCount} changes',
      SyncActivity.blocked => 'Sync requires attention',
    };
  }
}
