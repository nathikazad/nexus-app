import 'package:nx_notes/application/ports/session_store.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

typedef SessionProbeResult = offline.SessionProbeResult;
typedef SessionMode = offline.SessionMode;

class SessionRestoreResult {
  const SessionRestoreResult({required this.mode, this.session});

  final SessionMode mode;
  final CachedSession? session;
}

typedef SessionProbe =
    Future<SessionProbeResult> Function(CachedSession session);

class OfflineSessionRestorer {
  const OfflineSessionRestorer({required this.store, required this.probe});

  final SessionStore store;
  final SessionProbe probe;

  Future<SessionRestoreResult> restore() async {
    final result = await offline.OfflineSessionRestorer(
      store: _SharedSessionStore(store),
      probe: (session) => probe(CachedSession.fromShared(session)),
    ).restore();
    return SessionRestoreResult(
      mode: result.mode,
      session: result.session == null
          ? null
          : CachedSession.fromShared(result.session!),
    );
  }
}

enum DownloadedDataLogoutPolicy { retain, erase }

typedef LocalPartitionEraser = Future<void> Function(String accountKey);

class OfflineLogout {
  const OfflineLogout({required this.store, required this.erasePartition});

  final SessionStore store;
  final LocalPartitionEraser erasePartition;

  Future<void> run({
    required CachedSession session,
    required DownloadedDataLogoutPolicy downloadedData,
  }) async {
    await store.clear();
    if (downloadedData == DownloadedDataLogoutPolicy.erase) {
      await erasePartition(session.accountKey);
    }
  }
}

/// Preserves the installed Nx Notes preference keys while sharing the generic
/// session restoration policy with nx_offline.
final class _SharedSessionStore implements offline.CachedSessionStore {
  const _SharedSessionStore(this.store);

  final SessionStore store;

  @override
  Future<void> clear() => store.clear();

  @override
  Future<offline.CachedSession?> load() async => (await store.load())?.shared;

  @override
  Future<void> save(offline.CachedSession session) {
    return store.save(CachedSession.fromShared(session));
  }
}
