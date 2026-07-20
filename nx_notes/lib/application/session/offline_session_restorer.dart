import 'package:nx_notes/application/ports/session_store.dart';

enum SessionProbeResult { available, unreachable, unauthorized }

enum SessionMode { online, offline, loginRequired }

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
    final session = await store.load();
    if (session == null) {
      return const SessionRestoreResult(mode: SessionMode.loginRequired);
    }
    final result = await probe(session);
    return switch (result) {
      SessionProbeResult.available => SessionRestoreResult(
        mode: SessionMode.online,
        session: session,
      ),
      SessionProbeResult.unreachable => SessionRestoreResult(
        mode: SessionMode.offline,
        session: session,
      ),
      SessionProbeResult.unauthorized => _reject(),
    };
  }

  Future<SessionRestoreResult> _reject() async {
    await store.clear();
    return const SessionRestoreResult(mode: SessionMode.loginRequired);
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
