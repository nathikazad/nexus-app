import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';

import 'backend_presets.dart';
import 'oidc_config.dart';
import 'user.dart';
import 'session_availability.dart';

class NexusIdentity {
  const NexusIdentity({required this.userId});

  final String userId;
}

class NexusOidcService {
  OidcUserManager? _manager;
  BackendPreset? _preset;
  String? _clientAppId;
  BackendPreset? _restorePreset;
  String? _restoreClientAppId;
  Future<void>? _initializing;

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
    final manager = OidcUserManager.lazy(
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
      ),
    );
    await manager.init();
    _manager = manager;
    _preset = preset;
    _clientAppId = clientAppId;
  }

  Future<NexusIdentity?> restore(
    BackendPreset preset,
    String clientAppId,
  ) async {
    _restorePreset = preset;
    _restoreClientAppId = clientAppId;
    return withAuthAvailability(() async {
      await _ensureInitialized();
      if (_manager!.currentUser == null) return null;
      return _loadIdentity(preset);
    });
  }

  Future<NexusIdentity> signIn(
    BackendPreset preset,
    String clientAppId, {
    AuthLoginProfile? profile,
  }) async {
    _restorePreset = preset;
    _restoreClientAppId = clientAppId;
    await _ensureInitialized();
    final user = await _manager!.loginAuthorizationCodeFlow(
      loginHint: profile?.loginHint,
    );
    if (user == null) throw Exception('Sign-in was cancelled');
    final identity = await _loadIdentity(preset);
    if (profile != null && identity.userId != profile.userId) {
      await _manager!.forgetUser();
      throw Exception(
        'Please sign in as ${profile.label}. A different account was authenticated.',
      );
    }
    return identity;
  }

  Future<String> accessToken({bool forceRefresh = false}) async {
    // A cold offline restore may have failed before constructing the manager.
    // Retry that initialization on a later request after the network returns.
    await withAuthAvailability(_ensureInitialized);
    final token = await _manager?.getAccessToken(forceRefresh: forceRefresh);
    if (token == null || token.isEmpty) {
      throw Exception('Your sign-in session has expired');
    }
    return token;
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
    final manager = _manager;
    if (manager != null && manager.currentUser != null) await manager.logout();
  }
}

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
