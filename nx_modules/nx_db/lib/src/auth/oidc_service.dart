import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';

import '../core/config/backend_presets.dart';
import 'oidc_config.dart';

class NexusIdentity {
  const NexusIdentity({required this.userId});

  final String userId;
}

class NexusOidcService {
  static const _useInsecureLocalStore = bool.fromEnvironment(
    'NEXUS_INSECURE_LOCAL_OIDC_STORE',
  );

  OidcUserManager? _manager;
  BackendPreset? _preset;
  String? _clientAppId;

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
        // Unsigned local macOS builds cannot use Keychain Sharing. Keep the
        // plaintext fallback explicit and opt-in; signed/release builds always
        // use hardened secure storage.
        secureStorageInstance: _useInsecureLocalStore
            ? null
            : OidcDefaultStore.createHardenedSecureStorage(),
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
    await _initialize(preset, clientAppId);
    if (_manager!.currentUser == null) return null;
    return _loadIdentity(preset);
  }

  Future<NexusIdentity> signIn(BackendPreset preset, String clientAppId) async {
    await _initialize(preset, clientAppId);
    final user = await _manager!.loginAuthorizationCodeFlow();
    if (user == null) throw Exception('Sign-in was cancelled');
    return _loadIdentity(preset);
  }

  Future<String> accessToken({bool forceRefresh = false}) async {
    final token = await _manager?.getAccessToken(forceRefresh: forceRefresh);
    if (token == null || token.isEmpty) {
      throw Exception('Your sign-in session has expired');
    }
    return token;
  }

  Future<NexusIdentity> _loadIdentity(BackendPreset preset) async {
    final token = await accessToken();
    final response = await http
        .get(
          Uri.parse('${resolve(preset).imageHttp}/v1/me'),
          headers: {'authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(
        response.statusCode == 404
            ? 'This account is not linked to a Nexus user yet'
            : 'Could not load your Nexus identity (${response.statusCode})',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final principal = json['principal'] as Map<String, dynamic>?;
    final userId = principal?['user_id']?.toString() ?? '';
    if (userId.isEmpty)
      throw const FormatException('Nexus identity has no user ID');
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
