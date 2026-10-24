import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';

import 'backend_presets.dart';
import 'auth_telemetry.dart';
import 'oidc_config.dart';
import 'user.dart';
import 'session_availability.dart';
import 'diagnostic_oidc_manager.dart';
import 'flows/auth_flow.dart';

class NexusIdentity {
  const NexusIdentity({required this.userId});

  final String userId;
}

class RejectedOidcSession {
  const RejectedOidcSession(this.preset, this.clientAppId);
  final BackendPreset preset;
  final String clientAppId;
}

class NexusOidcService {
  NexusOidcService({AuthTelemetryRecorder? telemetry})
    : _telemetry = telemetry ?? authTelemetryRecorder;

  final AuthTelemetryRecorder _telemetry;
  final _rejections = StreamController<RejectedOidcSession>.broadcast(
    sync: true,
  );
  Stream<RejectedOidcSession> get rejections => _rejections.stream;
  int _sessionGeneration = 0;

  void prepareRestore(
    BackendPreset preset,
    String clientAppId, {
    String? userId,
  }) {
    _restorePreset = preset;
    _restoreClientAppId = clientAppId;
    _telemetryUserId = userId;
  }

  DiagnosticOidcUserManager? _manager;
  BackendPreset? _preset;
  String? _clientAppId;
  BackendPreset? _restorePreset;
  String? _restoreClientAppId;
  String? _telemetryUserId;
  Future<void>? _initializing;
  StreamSubscription<OidcEvent>? _eventSubscription;
  StreamSubscription<OidcUser?>? _userSubscription;
  DateTime? _lastTokenCreationTime;
  DateTime? _refreshStartedForTokenCreation;

  Future<void> _ensureInitialized() async {
    final preset = _restorePreset;
    final clientAppId = _restoreClientAppId;
    if (preset == null || clientAppId == null) return;
    final pending = _initializing;
    if (pending != null) return pending;
    final initializing = _initialize(preset, clientAppId);
    _initializing = initializing;
    try {
      await initializing;
    } finally {
      if (identical(_initializing, initializing)) _initializing = null;
    }
  }

  Future<void> _initialize(BackendPreset preset, String clientAppId) async {
    if (_manager != null && _preset == preset && _clientAppId == clientAppId) {
      return;
    }
    final config = await fetchNexusOidcConfig(preset, clientAppId: clientAppId);
    final manager = DiagnosticOidcUserManager.lazy(
      id: 'nexus-${preset.key}-$clientAppId',
      discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
        config.issuer,
      ),
      clientCredentials: OidcClientAuthentication.none(
        clientId: config.clientId,
      ),
      store: OidcDefaultStore(
        secureStorageInstance: OidcDefaultStore.createHardenedSecureStorage(),
      ),
      settings: OidcUserManagerSettings(
        redirectUri: config.redirectUri,
        postLogoutRedirectUri: config.logoutUri,
        scope: config.scopes,
        strictIssuerValidation: true,
        expectedIssuer: config.issuer,
        allowedAudiences: config.allowedAudiences,
        allowedIdTokenAlgorithms: const ['RS256'],
        supportOfflineAuth: true,
        options: nexusAuthFlowOptions,
      ),
    );
    await manager.init();
    await _eventSubscription?.cancel();
    await _userSubscription?.cancel();
    _manager = manager;
    _preset = preset;
    _clientAppId = clientAppId;
    _lastTokenCreationTime = manager.currentUser?.token.creationTime;
    _eventSubscription = manager.events().listen(_handleOidcEvent);
    _userSubscription = manager.userChanges().listen(_handleUserChange);
  }

  Future<NexusIdentity?> restore(
    BackendPreset preset,
    String clientAppId,
  ) async {
    _restorePreset = preset;
    _restoreClientAppId = clientAppId;
    return withAuthAvailability(() async {
      await _ensureInitialized();
      if (_manager!.currentUser == null) {
        final userId = _telemetryUserId;
        if (userId != null) {
          await _telemetry.endSession(
            app: clientAppId,
            userId: userId,
            event: 'session_missing',
          );
        }
        return null;
      }
      final identity = await _loadIdentity(preset);
      _telemetryUserId = identity.userId;
      await _telemetry.beginSession(
        app: clientAppId,
        userId: identity.userId,
        interactive: false,
        token: _tokenFields(_manager!.currentUser!.token),
      );
      unawaited(_flushTelemetry());
      return identity;
    });
  }

  Future<NexusIdentity> signIn(
    BackendPreset preset,
    String clientAppId, {
    AuthLoginProfile? profile,
  }) async {
    _sessionGeneration++;
    _restorePreset = preset;
    _restoreClientAppId = clientAppId;
    await _ensureInitialized();
    // Null also denotes rejected token claims in this library, not just cancel.
    final manager = _manager!;
    manager.validationReasons.clear();
    final user = await authorizeForPlatform(
      currentAuthFlowPlatform,
      manager,
      profile?.loginHint,
    );
    if (user == null) {
      if (manager.validationReasons.isNotEmpty) {
        throw AuthSignInValidationFailed(manager.validationReasons.toList());
      }
      throw const AuthSignInCancelled();
    }
    final identity = await _loadIdentity(preset);
    if (profile != null && identity.userId != profile.userId) {
      await _manager!.forgetUser();
      throw Exception(
        'Please sign in as ${profile.label}. A different account was authenticated.',
      );
    }
    _telemetryUserId = identity.userId;
    await _telemetry.beginSession(
      app: clientAppId,
      userId: identity.userId,
      interactive: true,
      token: _tokenFields(_manager!.currentUser!.token),
    );
    unawaited(_flushTelemetry());
    return identity;
  }

  Future<String> accessToken({bool forceRefresh = false}) async {
    final generation = _sessionGeneration;
    final preset = _restorePreset;
    final app = _restoreClientAppId;
    try {
      return await withAuthAvailability(() async {
        // Retry initialization after a cold offline startup.
        await _ensureInitialized();
        final currentToken = _manager?.currentUser?.token;
        if (currentToken != null &&
            (forceRefresh ||
                currentToken.isAccessTokenAboutToExpire(
                  tolerance: const Duration(seconds: 30),
                ))) {
          _recordRefreshStarted(
            forceRefresh ? 'forced' : 'on_demand',
            currentToken,
          );
        }
        final token = await _manager?.getAccessToken(
          forceRefresh: forceRefresh,
        );
        if (token == null || token.isEmpty) {
          throw const AuthSessionRejected();
        }
        return token;
      });
    } on AuthSessionRejected {
      final userId = _telemetryUserId;
      if (userId != null && app != null) {
        await _telemetry.endSession(
          app: app,
          userId: userId,
          event: 'session_rejected',
        );
      }
      if (generation == _sessionGeneration && preset != null && app != null) {
        _rejections.add(RejectedOidcSession(preset, app));
      }
      rethrow;
    }
  }

  Future<NexusIdentity> _loadIdentity(
    BackendPreset preset, {
    bool forceRefresh = false,
  }) async {
    final token = await accessToken(forceRefresh: forceRefresh);
    final response = await http
        .get(
          Uri.parse('${resolve(preset).imageHttp}/v1/me'),
          headers: {'authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      if (response.statusCode == 401 && !forceRefresh) {
        return _loadIdentity(preset, forceRefresh: true);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const AuthSessionRejected();
      }
      if (response.statusCode >= 500 || response.statusCode == 429) {
        throw const AuthServiceUnavailable();
      }
      throw Exception(
        response.statusCode == 404
            ? 'This account is not linked to a Nexus user yet'
            : 'Could not load your Nexus identity (${response.statusCode})',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final principal = json['principal'] as Map<String, dynamic>?;
    final userId = principal?['user_id']?.toString() ?? '';
    if (userId.isEmpty) {
      throw const FormatException('Nexus identity has no user ID');
    }
    return NexusIdentity(userId: userId);
  }

  Future<void> logout() async {
    _sessionGeneration++;
    final manager = _manager;
    final userId = _telemetryUserId;
    final app = _restoreClientAppId;
    if (userId != null && app != null) {
      await _telemetry.endSession(
        app: app,
        userId: userId,
        event: 'signed_out',
      );
      unawaited(_flushTelemetry());
    }
    if (manager != null && manager.currentUser != null) await manager.logout();
    _telemetryUserId = null;
  }

  void _handleOidcEvent(OidcEvent event) {
    if (event is OidcTokenExpiringEvent) {
      _recordRefreshStarted('auto_expiry', event.currentToken);
      return;
    }
    if (event is OidcTokenRefreshFailedEvent) {
      final userId = _telemetryUserId;
      final app = _restoreClientAppId;
      if (userId != null && app != null) {
        unawaited(
          _telemetry.enqueue(
            app: app,
            userId: userId,
            event: 'token_refresh_failed',
            fields: {
              'source': event.source.name,
              'failure_kind': event.kind.name,
              'will_retry': event.willRetry,
              if (event.oauthErrorCode != null)
                'oauth_error_code': event.oauthErrorCode,
              if (event.httpStatusCode != null)
                'http_status_code': event.httpStatusCode,
            },
            at: event.at,
          ),
        );
      }
      _refreshStartedForTokenCreation = null;
    }
  }

  void _handleUserChange(OidcUser? user) {
    final token = user?.token;
    if (token == null) return;
    final previous = _lastTokenCreationTime;
    _lastTokenCreationTime = token.creationTime;
    if (previous == null || !token.creationTime.isAfter(previous)) return;
    final userId = _telemetryUserId;
    final app = _restoreClientAppId;
    if (userId != null && app != null) {
      unawaited(
        _telemetry.enqueue(
          app: app,
          userId: userId,
          event: 'token_refresh_succeeded',
          fields: _tokenFields(token),
        ),
      );
      unawaited(_flushTelemetry());
    }
    _refreshStartedForTokenCreation = null;
  }

  void _recordRefreshStarted(String source, OidcToken token) {
    if (_refreshStartedForTokenCreation == token.creationTime) return;
    _refreshStartedForTokenCreation = token.creationTime;
    final userId = _telemetryUserId;
    final app = _restoreClientAppId;
    if (userId == null || app == null) return;
    unawaited(
      _telemetry.enqueue(
        app: app,
        userId: userId,
        event: 'token_refresh_started',
        fields: {'source': source, ..._tokenFields(token)},
      ),
    );
  }

  Future<void> _flushTelemetry() async {
    final manager = _manager;
    final preset = _restorePreset;
    final app = _restoreClientAppId;
    final userId = _telemetryUserId;
    final token = manager?.currentUser?.token.accessToken;
    if (preset == null || app == null || userId == null || token == null)
      return;
    await _telemetry.flush(
      preset: preset,
      app: app,
      userId: userId,
      accessToken: token,
    );
  }
}

Map<String, Object?> _tokenFields(OidcToken token) => {
  'access_token_issued_at': token.creationTime.toUtc().toIso8601String(),
  if (token.calculateExpiresAt() case final expiresAt?)
    'access_token_expires_at': expiresAt.toUtc().toIso8601String(),
  if (token.expiresIn case final lifetime?)
    'access_token_lifetime_seconds': lifetime.inSeconds,
  'has_refresh_token': token.refreshToken?.isNotEmpty ?? false,
};

final nexusOidcService = NexusOidcService();

Future<Map<String, String>> nexusAuthHeaders(
  BackendPreset preset,
  String userId, {
  bool forceRefresh = false,
}) async {
  if (!preset.requiresOidc) return {'x-user-id': userId};
  final token = await nexusOidcService.accessToken(forceRefresh: forceRefresh);
  return {'authorization': 'Bearer $token'};
}
