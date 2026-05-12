import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gql/language.dart' show printNode;
import 'package:gql/ast.dart' show OperationType;
import 'package:graphql_flutter/graphql_flutter.dart';

import '../config/backend_presets.dart';
import '../config/graphql_http_config.dart';
import 'db_audit_context.dart';

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

Link dbAuditContextLink(String sourceKind) {
  return Link.function((Request request, [NextLink? forward]) {
    if (forward == null) {
      return Stream<Response>.error(
        StateError('DbAuditContextLink: forward is null'),
      );
    }
    if (request.operation.getOperationType() != OperationType.mutation) {
      return forward(request);
    }

    final context = currentDbAuditContext() ??
        DbAuditContext.create(
          sourceKind: sourceKind,
          sourceId: request.operation.operationName,
          sourceLabel: request.operation.operationName,
        );
    final auditedRequest = request.updateContextEntry<HttpLinkHeaders>(
      (headers) => HttpLinkHeaders(
        headers: <String, String>{
          ...headers?.headers ?? <String, String>{},
          ...context.toHeaders(fallbackSourceKind: sourceKind),
        },
      ),
    );
    return forward(auditedRequest);
  });
}

class GraphQLConfig {
  static String get defaultEndpoint =>
      resolve(BackendPreset.defaultPreset).graphqlHttp;
  static const String defaultUserId = '1';
}

GraphQLClient createClient(
  String endpoint,
  String userId, {
  String auditSourceKind = 'nx_mobile',
}) {
  final ep = normalizeHttpEndpointForCf(endpoint);
  final defaultHeaders = buildHttpLinkDefaultHeaders(ep, userId);

  final httpLink = HttpLink(
    ep,
    defaultHeaders: defaultHeaders,
  );

  final wsUrl =
      ep.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');

  final wsLink = WebSocketLink(
    wsUrl,
    config: SocketClientConfig(
      autoReconnect: true,
      inactivityTimeout: const Duration(seconds: 30),
      initialPayload: {'x-user-id': userId},
      headers: defaultHeaders,
    ),
  );

  final transport = Link.split(
    (request) => request.isSubscription,
    wsLink,
    httpLink,
  );

  final link = Link.from([
    _kgqlRequestLogLink(),
    dbAuditContextLink(auditSourceKind),
    transport,
  ]);

  return GraphQLClient(
    link: link,
    cache: GraphQLCache(),
  );
}
