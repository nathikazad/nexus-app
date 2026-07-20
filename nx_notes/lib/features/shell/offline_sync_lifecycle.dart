import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/application/sync/document_sync_engine.dart';
import 'package:nx_notes/composition/offline_providers.dart';

class OfflineSyncLifecycle extends ConsumerStatefulWidget {
  const OfflineSyncLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<OfflineSyncLifecycle> createState() =>
      _OfflineSyncLifecycleState();
}

class _OfflineSyncLifecycleState extends ConsumerState<OfflineSyncLifecycle>
    with WidgetsBindingObserver {
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = ref
        .read(connectivityMonitorProvider)
        .onlineChanges
        .where((online) => online)
        .listen((_) => _synchronize(SyncReason.connectivityRestored));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_connectivitySubscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _synchronize(SyncReason.appStarted);
    }
  }

  void _synchronize(SyncReason reason) {
    final service = ref.read(offlineNotesServiceProvider);
    if (service != null) unawaited(service.synchronize(reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(offlineNotesServiceProvider, (previous, next) {
      if (previous == null && next != null) {
        unawaited(next.synchronize(reason: SyncReason.appStarted));
      }
    });
    return widget.child;
  }
}
