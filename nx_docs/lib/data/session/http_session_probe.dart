import 'package:http/http.dart' as http;
import 'package:nx_db/auth.dart';
import 'package:nx_docs/application/ports/session_store.dart';
import 'package:nx_docs/application/session/offline_session_restorer.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

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
