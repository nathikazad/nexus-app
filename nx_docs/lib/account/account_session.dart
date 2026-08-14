import 'package:http/http.dart' as http;
import 'package:nx_db/auth.dart';
import 'package:nx_offline/nx_offline.dart' as offline;
import 'package:shared_preferences/shared_preferences.dart';

class CachedSession {
  const CachedSession({required this.userId, required this.backendPreset})
    : assert(userId != ''),
      assert(backendPreset != '');

  final String userId;
  final String backendPreset;

  static const String serverId = 'nexus-primary';
  static const String application = 'nx_notes';

  offline.CachedSession get shared => offline.CachedSession(
    serverId: serverId,
    userId: userId,
    application: application,
    route: backendPreset,
  );

  factory CachedSession.fromShared(offline.CachedSession session) {
    if (session.serverId != serverId || session.application != application) {
      throw StateError('Cached session does not belong to Nexus Docs');
    }
    return CachedSession(userId: session.userId, backendPreset: session.route);
  }

  /// Endpoint presets are alternate routes to the same database. They must
  /// never partition a user's local cache or outbox.
  String get accountKey => 'user:$userId';
}

abstract interface class SessionStore {
  Future<CachedSession?> load();

  Future<void> save(CachedSession session);

  Future<void> clear();
}

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

/// Preserves the installed Nexus Docs preference keys while sharing the generic
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

class PreferencesSessionStore implements SessionStore {
  PreferencesSessionStore(this.preferences);

  static const String userIdKey = 'nx_notes.offline_session.user_id';
  static const String backendPresetKey =
      'nx_notes.offline_session.backend_preset';

  final SharedPreferences preferences;

  @override
  Future<CachedSession?> load() async {
    final userId = preferences.getString(userIdKey);
    final preset = preferences.getString(backendPresetKey);
    if (userId == null || userId.isEmpty || preset == null || preset.isEmpty) {
      return null;
    }
    return CachedSession(userId: userId, backendPreset: preset);
  }

  @override
  Future<void> save(CachedSession session) async {
    await preferences.setString(userIdKey, session.userId);
    await preferences.setString(backendPresetKey, session.backendPreset);
  }

  @override
  Future<void> clear() async {
    await preferences.remove(userIdKey);
    await preferences.remove(backendPresetKey);
  }
}

class HttpSessionProbe {
  HttpSessionProbe({
    http.Client? client,
    this.timeout = const Duration(seconds: 2),
  }) : _probe = offline.HttpSessionProbe(
         endpointFor: (session) {
           final preset = BackendPreset.fromKey(session.route)!;
           return Uri.parse(resolve(preset).graphqlHttp);
         },
         headersFor: (session) {
           final preset = BackendPreset.fromKey(session.route)!;
           final endpoint = resolve(preset).graphqlHttp;
           return buildHttpLinkDefaultHeaders(endpoint, session.userId);
         },
         client: client,
         timeout: timeout,
       );

  final Duration timeout;
  final offline.HttpSessionProbe _probe;

  Future<SessionProbeResult> call(CachedSession session) async {
    final preset = BackendPreset.fromKey(session.backendPreset);
    if (preset == null) return SessionProbeResult.unauthorized;
    return _probe(session.shared);
  }

  void close() => _probe.close();
}

typedef AuthenticationLogout = Future<void> Function();
typedef OfflineSessionInvalidator = void Function();

/// Ends the authenticated and cached-offline sessions without deleting the
/// account's downloaded Notes database.
final class AccountLogoutService {
  const AccountLogoutService({
    required this.sessionStore,
    required this.logoutAuthentication,
    required this.invalidateOfflineSession,
  });

  final SessionStore sessionStore;
  final AuthenticationLogout logoutAuthentication;
  final OfflineSessionInvalidator invalidateOfflineSession;

  Future<void> logout() async {
    await sessionStore.clear();
    try {
      await logoutAuthentication();
    } finally {
      invalidateOfflineSession();
    }
  }
}
