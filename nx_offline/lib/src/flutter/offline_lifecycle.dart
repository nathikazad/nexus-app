import 'dart:async';

import 'package:flutter/material.dart';

import '../core/sync_models.dart';
import '../sync/sync_coordinator.dart';

final class OfflineLifecycle extends StatefulWidget {
  const OfflineLifecycle({
    required this.coordinator,
    required this.child,
    this.onlineChanges,
    super.key,
  });

  final SyncCoordinator? coordinator;
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
    if (!identical(oldWidget.coordinator, widget.coordinator)) {
      _synchronize(SyncReason.appStarted);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _synchronize(SyncReason.appStarted);
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
    final coordinator = widget.coordinator;
    if (coordinator != null) {
      unawaited(coordinator.synchronize(reason: reason));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

final class SyncStatusView extends StatelessWidget {
  const SyncStatusView({required this.coordinator, this.textStyle, super.key});

  final SyncCoordinator coordinator;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: coordinator.statusChanges,
      initialData: coordinator.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? coordinator.status;
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
