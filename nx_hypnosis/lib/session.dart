import 'cached_session.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:nx_offline/nx_offline.dart';
import 'offline_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_auth/nx_auth.dart';
import 'app.dart';
import 'remote_collection.dart';
import 'package:nx_db/nx_db.dart' as db;
import 'package:nx_db/app_sync.dart' as sync;

class HypnosisSession extends ConsumerWidget {
  const HypnosisSession({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider);
    final cached = ref.watch(activeHypnosisUserProvider);
    final user = cached.value ?? session.value;
    if (user != null) {
      return ConnectedHypnosis(
        key: ValueKey('${user.preset}-${user.userId}'),
        user: user,
      );
    }
    return MaterialApp(
      title: 'NX Hypnosis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(primary: ink),
        scaffoldBackgroundColor: paper,
      ),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'NX Hypnosis',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              if (session.isLoading || cached.isLoading)
                const CircularProgressIndicator()
              else
                FilledButton(
                  onPressed: () => ref
                      .read(authProvider.notifier)
                      .login('', BackendPreset.hosted),
                  child: const Text('Sign in with Nexus'),
                ),
              if (session.hasError)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Sign-in could not be completed. Please try again.',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConnectedHypnosis extends ConsumerStatefulWidget {
  const ConnectedHypnosis({super.key, required this.user});
  final User user;
  @override
  ConsumerState<ConnectedHypnosis> createState() => _ConnectedHypnosisState();
}

class _ConnectedHypnosisState extends ConsumerState<ConnectedHypnosis> {
  bool _loaded = false;
  StreamSubscription<SyncStatus>? _initialSync;
  late final data = RemoteCollection(
    widget.user,
    stateSession: () =>
        AppDataPolicy.current.downloadsLibrary &&
            sync.appStateSyncEnabled &&
            ref.read(authProvider).value != null
        ? sync.AppSyncClient.forOwner(
            this,
            ref.read(db.graphqlClientProvider),
            'hypnosis',
          ).session
        : null,
    cache: !AppDataPolicy.current.storesOfflineData
        ? null
        : HypnosisCache.application(
            AccountIdentity(
              serverId: 'nexus-primary',
              userId: widget.user.userId,
              application: 'nx_hypnosis',
            ).key,
          ),
  );
  late final onlineChanges = Connectivity().onConnectivityChanged.map(
    (values) => !values.contains(ConnectivityResult.none),
  );
  // Keep one callback identity across rebuilds so lifecycle sync is not retriggered.
  // ignore: prefer_function_declarations_over_variables
  late final OfflineSynchronize synchronize = AppDataPolicy.current.select(
    native: () =>
        (reason) => data.refresh(reason: reason),
    web: () =>
        (reason) => sync.appStateSyncEnabled
        ? sync.AppSyncClient.forOwner(
            this,
            ref.read(db.graphqlClientProvider),
            'hypnosis',
          ).refreshIfChanged(() => data.refresh(reason: reason))
        : data.refresh(reason: reason),
  );
  late Future<void> loading = data.initialize().then((_) {
    _loaded = true;
  });
  @override
  void initState() {
    super.initState();
    _initialSync = data.synchronizer.statusChanges.listen((status) {
      if (!_loaded && mounted && status.lastSyncedAt != null) {
        _loaded = true;
        setState(() => loading = Future.value());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_initialSync?.cancel());
    data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: loading,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return OfflineLifecycle(
          synchronize: synchronize,
          onlineChanges: !AppDataPolicy.current.storesOfflineData
              ? null
              : onlineChanges,
          remoteChanges: ref.watch(sync.appSyncChangesProvider('hypnosis')),
          checkInterval: sync.appStateSyncEnabled
              ? const Duration(seconds: 30)
              : null,
          child: HypnosisApp(
            collection: data,
            onLogout: () async {
              await (await hypnosisSessionStore()).clear();
              if (mounted) await ref.read(authProvider.notifier).logout();
            },
          ),
        );
      }
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: snapshot.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load your desires and tapes.'),
                      TextButton(
                        onPressed: () =>
                            setState(() => loading = data.initialize()),
                        child: const Text('Try again'),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(authProvider.notifier).logout(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );
}
