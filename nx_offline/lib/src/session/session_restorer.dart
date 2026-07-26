import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cached_session.dart';

enum SessionProbeResult { available, unreachable, unauthorized }

enum SessionMode { online, offline, loginRequired }

enum DownloadedDataLogoutPolicy { retain, erase }

final class SessionRestoreResult {
  const SessionRestoreResult({required this.mode, this.session});

  final SessionMode mode;
  final CachedSession? session;
}

typedef SessionProbe =
    Future<SessionProbeResult> Function(CachedSession session);
typedef LocalPartitionEraser = Future<void> Function(String accountKey);

final class OfflineSessionRestorer {
  const OfflineSessionRestorer({required this.store, required this.probe});

  final CachedSessionStore store;
  final SessionProbe probe;

  Future<SessionRestoreResult> restore() async {
    final session = await store.load();
    if (session == null) {
      return const SessionRestoreResult(mode: SessionMode.loginRequired);
    }
    return switch (await probe(session)) {
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

final class OfflineLogout {
  const OfflineLogout({required this.store, required this.erasePartition});

  final CachedSessionStore store;
  final LocalPartitionEraser erasePartition;

  Future<void> run({
    required CachedSession session,
    required DownloadedDataLogoutPolicy downloadedData,
  }) async {
    await store.clear();
    if (downloadedData == DownloadedDataLogoutPolicy.erase) {
      await erasePartition(session.account.key);
    }
  }
}

/// Generic HTTP probe suitable for a KGQL GraphQL endpoint.
///
/// Header construction remains application-owned so authentication details do
/// not leak into the reusable package.
final class HttpSessionProbe {
  HttpSessionProbe({
    required this.endpointFor,
    required this.headersFor,
    http.Client? client,
    this.timeout = const Duration(seconds: 2),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final Uri Function(CachedSession session) endpointFor;
  final Map<String, String> Function(CachedSession session) headersFor;
  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;

  Future<SessionProbeResult> call(CachedSession session) async {
    try {
      final response = await _client
          .post(
            endpointFor(session),
            headers: {
              'Content-Type': 'application/json',
              ...headersFor(session),
            },
            body: jsonEncode(const {'query': '{ __typename }'}),
          )
          .timeout(timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        return SessionProbeResult.unauthorized;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return SessionProbeResult.unreachable;
      }
      return SessionProbeResult.available;
    } on TimeoutException {
      return SessionProbeResult.unreachable;
    } catch (_) {
      return SessionProbeResult.unreachable;
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
