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
  piLan('pi_lan', 'Pi (LAN)'),
  piTailscale('pi_tailscale', 'Pi (Tailscale)'),
  piWan('pi_wan', 'Pi (WAN)');

  const BackendPreset(this.key, this.label);

  final String key;
  final String label;

  static BackendPreset? fromKey(String? s) {
    if (s == null || s.isEmpty) return null;
    for (final p in BackendPreset.values) {
      if (p.key == s) return p;
    }
    return null;
  }

  static const BackendPreset defaultPreset = piTailscale;
}

class BackendUrls {
  const BackendUrls({
    required this.graphqlHttp,
    required this.sockWs,
    required this.imageHttp,
  });

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
      return const BackendUrls(
        graphqlHttp: 'http://10.0.0.156:5001/graphql',
        sockWs: 'ws://10.0.0.156:8002',
        imageHttp: 'http://10.0.0.156:8001',
      );
    case BackendPreset.piTailscale:
      return const BackendUrls(
        graphqlHttp: 'http://100.108.43.37:5001/graphql',
        sockWs: 'ws://100.108.43.37:8002',
        imageHttp: 'http://100.108.43.37:8001',
      );
    case BackendPreset.piWan:
      return const BackendUrls(
        graphqlHttp: 'https://graphql.supacharger.ai/graphql',
        sockWs: 'wss://sock.supacharger.ai',
        imageHttp: 'https://sock.supacharger.ai',
      );
  }
}
