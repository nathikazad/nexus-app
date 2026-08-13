import 'package:graphql_flutter/graphql_flutter.dart';

import '../core/client/db_audit_context.dart';
import '../kgql/requests/set_model_request.dart';

const String _mutateCardLibraryMutation = r'''
mutation MutateCardLibrary(
  $data: JSON!
  $clientUpdatedAt: String
  $domainId: Int
) {
  mutateCardLibrary(
    data: $data
    clientUpdatedAt: $clientUpdatedAt
    domainId: $domainId
  )
}
''';

enum CardLibraryMutationStatus { applied, stale, deleted }

final class CardLibraryMutationResult {
  const CardLibraryMutationResult({
    required this.status,
    required this.entityId,
    this.updatedAt,
    this.entity,
  });

  final CardLibraryMutationStatus status;
  final int entityId;
  final DateTime? updatedAt;
  final Map<String, dynamic>? entity;
}

Future<CardLibraryMutationResult> mutateCardLibrary(
  GraphQLClient client,
  SetModelRequest request, {
  DateTime? clientUpdatedAt,
  int? domainId,
  DbAuditContext? auditContext,
  String auditSourceKind = 'nx_cards',
}) {
  final context = auditContext ??
      currentDbAuditContext() ??
      DbAuditContext.create(
        sourceKind: auditSourceKind,
        sourceId: _sourceId(request),
        sourceLabel: request.name ?? 'Cards mutation',
      );
  return runWithDbAuditContext(context, () async {
    final result = await client.mutate(
      MutationOptions(
        document: gql(_mutateCardLibraryMutation),
        variables: <String, dynamic>{
          'data': request.toJson(),
          'clientUpdatedAt': clientUpdatedAt?.toUtc().toIso8601String(),
          if (domainId != null) 'domainId': domainId,
        },
      ),
    );
    if (result.hasException) throw result.exception!;

    final payload = _jsonMap(result.data?['mutateCardLibrary']);
    final status = switch (payload['status']) {
      'APPLIED' => CardLibraryMutationStatus.applied,
      'STALE' => CardLibraryMutationStatus.stale,
      'DELETED' => CardLibraryMutationStatus.deleted,
      final Object? value => throw StateError(
          'Unknown mutateCardLibrary status: $value',
        ),
    };
    final id = payload['id'];
    if (id is! int) {
      throw StateError('mutateCardLibrary did not return an integer id');
    }
    return CardLibraryMutationResult(
      status: status,
      entityId: id,
      updatedAt: _parseTimestamp(payload['updated_at']),
      entity: _optionalJsonMap(payload['entity']),
    );
  });
}

Map<String, dynamic> _jsonMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw StateError('Expected JSON object, received $value');
}

Map<String, dynamic>? _optionalJsonMap(Object? value) {
  if (value == null) return null;
  return _jsonMap(value);
}

DateTime? _parseTimestamp(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final hasTimeZone =
      value.endsWith('Z') || RegExp(r'[+-]\d\d(?::?\d\d)?$').hasMatch(value);
  return DateTime.parse(hasTimeZone ? value : '${value}Z').toUtc();
}

String _sourceId(SetModelRequest request) {
  if (request.id != null) return 'card-library:${request.id}';
  return 'card-library:create:${request.modelType ?? 'unknown'}';
}
