import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    if (!ref.read(offlineEnabledProvider)) return;
    _connectivitySubscription = ref
        .read(connectivityMonitorProvider)
        .onlineChanges
        .where((online) => online)
        .listen((_) => _syncLibrary());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_connectivitySubscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (ref.read(offlineEnabledProvider) &&
        state == AppLifecycleState.resumed) {
      _syncLibrary();
    }
  }

  void _syncLibrary() {
    final workspace = ref.read(notesWorkspaceProvider);
    if (workspace != null) {
      unawaited(workspace.syncLibrary().catchError((Object _) {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(offlineEnabledProvider)) {
      ref.listen(notesWorkspaceProvider, (previous, next) {
        if (previous == null && next != null) {
          unawaited(next.syncLibrary().catchError((Object _) {}));
        }
      });
    }
    return widget.child;
  }
}
