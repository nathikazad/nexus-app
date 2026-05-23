import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gql/ast.dart' show OperationType;
import 'package:gql/language.dart' show printNode;
import 'package:gql_exec/gql_exec.dart' show RequestExtensionsThunk;
import 'package:graphql_flutter/graphql_flutter.dart';

import '../config/backend_presets.dart';
import '../config/graphql_http_config.dart';
import 'db_audit_context.dart';

export '../config/graphql_http_config.dart';

const bool _kLogKgqlFromDefine = bool.fromEnvironment(
  'NX_GRAPHQL_LOG',
  defaultValue: false,
);

const int _kMaxGraphQlLogChars = 4000;
const int _kMaxGraphQlLogStringChars = 500;
const int _kMaxGraphQlLogCollectionItems = 20;
const int _kMaxGraphQlLogDepth = 6;

bool _shouldLogKgqlQueries() => _kLogKgqlFromDefine;

void _logOutgoingGraphQlRequest(Request request) {
  final name = request.operation.operationName ?? '(anonymous)';
  final doc = _truncateLogText(printNode(request.operation.document));
  final vars = formatGraphQlLogValue(request.variables);
  debugPrint('[nx_db:GraphQL] → $name\n$doc');
  debugPrint('[nx_db:GraphQL] variables:\n$vars');
}

@visibleForTesting
String formatGraphQlLogValue(Object? value) {
  final truncated = _truncateGraphQlLogValue(value);
  final encoded = switch (truncated) {
    final String s => s,
    _ => _encodeGraphQlLogValue(truncated),
  };
  return _truncateLogText(encoded);
}

String _encodeGraphQlLogValue(Object? value) {
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return value.toString();
  }
}

Object? _truncateGraphQlLogValue(Object? value, {int depth = 0}) {
  if (value == null || value is num || value is bool) return value;
  if (value is String) {
    if (value.length <= _kMaxGraphQlLogStringChars) return value;
    return '${value.substring(0, _kMaxGraphQlLogStringChars)}... '
        '<truncated ${value.length - _kMaxGraphQlLogStringChars} chars>';
  }
  if (depth >= _kMaxGraphQlLogDepth) {
    return '<truncated: max depth $_kMaxGraphQlLogDepth>';
  }
  if (value is Map) {
    final entries = value.entries.take(_kMaxGraphQlLogCollectionItems).toList();
    final result = <String, Object?>{
      for (final entry in entries)
        entry.key.toString(): _truncateGraphQlLogValue(
          entry.value,
          depth: depth + 1,
        ),
    };
    final extra = value.length - entries.length;
    if (extra > 0) {
      result['...'] = '<truncated $extra entries>';
    }
    return result;
  }
  if (value is Iterable) {
    final items = value.take(_kMaxGraphQlLogCollectionItems).toList();
    final result = <Object?>[
      for (final item in items)
        _truncateGraphQlLogValue(item, depth: depth + 1),
    ];
    final extra = value.length - items.length;
    if (extra > 0) {
      result.add('<truncated $extra items>');
    }
    return result;
  }
  return _truncateGraphQlLogValue(value.toString(), depth: depth);
}

String _truncateLogText(String value) {
  if (value.length <= _kMaxGraphQlLogChars) return value;
  return '${value.substring(0, _kMaxGraphQlLogChars)}... '
      '<truncated ${value.length - _kMaxGraphQlLogChars} chars>';
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
    final previousExtensions = request.context.entry<RequestExtensionsThunk>();
    final audit = context.toNexusAudit(fallbackSourceKind: sourceKind);
    final auditedRequest = request.withContextEntry(
      RequestExtensionsThunk((request) {
        final existing = previousExtensions?.getRequestExtensions(request);
        return <String, dynamic>{
          if (existing is Map) ...existing,
          'nexusAudit': audit,
        };
      }),
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
