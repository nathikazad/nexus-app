import 'package:graphql_flutter/graphql_flutter.dart';

import '../config/backend_presets.dart';
import '../config/cf_access.dart';
import '../config/graphql_http_config.dart';

export '../config/graphql_http_config.dart';

class GraphQLConfig {
  static String get defaultEndpoint =>
      resolve(BackendPreset.defaultPreset).graphqlHttp;
  static const String defaultUserId = '1';
}

GraphQLClient createClient(String endpoint, String userId) {
  final ep = normalizeHttpEndpointForCf(endpoint);
  final attachCf = CfAccess.shouldAttachHeaders(ep);
  final cf = attachCf ? CfAccess.headers : const <String, String>{};

  final httpLink = HttpLink(
    ep,
    defaultHeaders: buildHttpLinkDefaultHeaders(ep, userId),
  );

  final wsUrl = ep
      .replaceFirst('http://', 'ws://')
      .replaceFirst('https://', 'wss://');

  final wsLink = WebSocketLink(
    wsUrl,
    config: SocketClientConfig(
      autoReconnect: true,
      inactivityTimeout: const Duration(seconds: 30),
      initialPayload: {'x-user-id': userId},
      headers: attachCf ? cf : null,
    ),
  );

  final link = Link.split(
    (request) => request.isSubscription,
    wsLink,
    httpLink,
  );

  return GraphQLClient(
    link: link,
    cache: GraphQLCache(),
  );
}
