/// SharedPreferences keys for auth and backend configuration.
abstract final class PrefsKeys {
  PrefsKeys._();

  static const userId = 'auth_user_id';
  static const endpoint = 'auth_endpoint';
  static const backendPreset = 'auth_backend_preset';
  static const sockWsUrl = 'auth_sock_ws_url';
}

/// Fixed backend environments; all URLs derive from [resolve].
enum BackendPreset {
  /// LAN dev host at `10.0.0.210` — not the same as Docker on this machine (use [localhost]).
  laptop('laptop', 'Laptop (10.0.0.210)'),

  /// Same URLs as [kIntegrationTestBackendUrls]: GraphQL on this host (e.g. Docker `-p 5001:5001`).
  localhost('localhost', 'Local (127.0.0.1 / Docker)'),
  piLan('pi_lan', 'Pi Caddy (LAN)'),
  piTailscale('pi_tailscale', 'Pi Caddy (Tailscale)'),
  piWan('pi_wan', 'Hosted Nexus');

  const BackendPreset(this.key, this.label);

  final String key;
  final String label;

  /// Hosted Nexus authenticates through the self-hosted OIDC provider.
  /// Local Pi/development presets remain direct-only until that deployment
  /// explicitly enables its own identity provider.
  bool get requiresOidc => this == BackendPreset.piWan;

  static BackendPreset? fromKey(String? s) {
    if (s == null || s.isEmpty) return null;
    for (final p in BackendPreset.values) {
      if (p.key == s) return p;
    }
    return null;
  }

  static const BackendPreset defaultPreset = piWan;
}

class BackendUrls {
  const BackendUrls({
    required this.graphqlHttp,
    required this.sockWs,
    required this.imageHttp,
  });

  /// Builds the standard Nexus routes exposed by Caddy from one HTTP origin.
  factory BackendUrls.fromOrigin(String origin) {
    final uri = Uri.parse(origin);
    if ((uri.scheme != 'http' && uri.scheme != 'https') ||
        !uri.hasAuthority ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(origin, 'origin', 'Must be an HTTP(S) origin');
    }

    final httpOrigin = uri.replace(path: '').toString();
    final wsOrigin = uri
        .replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws', path: '')
        .toString();
    return BackendUrls(
      graphqlHttp: '$httpOrigin/graphql',
      sockWs: '$wsOrigin/realtime',
      imageHttp: httpOrigin,
    );
  }

  final String graphqlHttp;
  final String sockWs;
  final String imageHttp;
}

/// URLs for integration tests with PGDB on the same machine as the test runner.
/// Same as [BackendPreset.localhost] / Docker port maps on `127.0.0.1`.
const kIntegrationTestBackendUrls = BackendUrls(
  graphqlHttp: 'http://127.0.0.1:5001/graphql',
  sockWs: 'ws://127.0.0.1:8002',
  imageHttp: 'http://127.0.0.1:8001',
);

BackendUrls resolve(BackendPreset p) {
  switch (p) {
    case BackendPreset.laptop:
      return const BackendUrls(
        graphqlHttp: 'http://10.0.0.210:5001/graphql',
        sockWs: 'ws://10.0.0.210:8002',
        imageHttp: 'http://10.0.0.210:8001',
      );
    case BackendPreset.localhost:
      return kIntegrationTestBackendUrls;
    case BackendPreset.piLan:
      return BackendUrls.fromOrigin('http://10.0.0.156');
    case BackendPreset.piTailscale:
      return BackendUrls.fromOrigin('http://100.108.43.37');
    case BackendPreset.piWan:
      return BackendUrls.fromOrigin('https://nexus.kgql.io');
  }
}
