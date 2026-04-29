import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gql/language.dart' show printNode;
import 'package:graphql_flutter/graphql_flutter.dart';

import '../config/backend_presets.dart';
import '../config/cf_access.dart';
import '../config/graphql_http_config.dart';

export '../config/graphql_http_config.dart';

const bool _kLogKgqlFromDefine = bool.fromEnvironment(
  'NX_GRAPHQL_LOG',
  defaultValue: false,
);

bool _shouldLogKgqlQueries() => kDebugMode || _kLogKgqlFromDefine;

void _logOutgoingGraphQlRequest(Request request) {
  final name = request.operation.operationName ?? '(anonymous)';
  final doc = printNode(request.operation.document);
  String vars;
  try {
    vars = const JsonEncoder.withIndent('  ').convert(request.variables);
  } catch (_) {
    vars = request.variables.toString();
  }
  debugPrint('[nx_db:GraphQL] → $name\n$doc');
  debugPrint('[nx_db:GraphQL] variables:\n$vars');
}

Link _kgqlRequestLogLink() {
  return Link.function((Request request, [NextLink? forward]) {
    if (forward == null) {
      return Stream<Response>.error(
        StateError('KgqlRequestLogLink: forward is null'),
      );
    }
    if (_shouldLogKgqlQueries()) {
      _logOutgoingGraphQlRequest(request);
    }
    return forward(request);
  });
}

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

  final transport = Link.split(
    (request) => request.isSubscription,
    wsLink,
    httpLink,
  );

  final link = Link.from([
    _kgqlRequestLogLink(),
    transport,
  ]);

  return GraphQLClient(
    link: link,
    cache: GraphQLCache(),
  );
}
