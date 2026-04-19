import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_expense/data/expense/expense_set_model_request.dart';
import 'package:nx_expense/data/teller/expense_timeline_api.dart';
import 'package:nx_expense/data/transfer/transfer_mapper.dart';
import 'package:nx_expense/data/transfer/transfer_struct.dart';
import 'package:nx_expense/domain/expense/expense_summary.dart';
import 'package:nx_expense/domain/expense/model_names.dart';
import 'package:nx_expense/domain/transfer/transfer.dart';
import 'package:nx_expense/domain/transfer/transfer_repository.dart';

String _dateOnlyYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class KgqlTransferRepository implements TransferRepository {
  KgqlTransferRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadTransferSchema,
  })  : _client = client,
        _loadTransferSchema = loadTransferSchema;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadTransferSchema;

  SetModelRequest _transferRequest(TransferUpsert u) {
    final base = buildExpenseSetModelRequest(u);
    return SetModelRequest(
      id: base.id,
      modelType: base.id == null ? kTransferModelTypeName : null,
      name: base.name,
      description: base.description,
      attributes: base.attributes,
      relations: base.relations,
      tags: base.tags,
      traits: base.traits,
      delete: base.delete,
    );
  }

  @override
  Future<List<Transfer>> list({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final schema = await _loadTransferSchema();
    final struct = buildTransferStruct(schema);
    final rows = await fetchKgqlModels(
      _client,
      filter: {
        'model_type': kTransferModelTypeName,
        'filters': [
          {
            'key': 'date',
            'op': '>=',
            'value': _dateOnlyYmd(rangeStart),
          },
          {
            'key': 'date',
            'op': '<=',
            'value': _dateOnlyYmd(rangeEnd),
          },
        ],
      },
      struct: struct,
    );
    return rows.map(transferFromModel).toList();
  }

  @override
  Future<Transfer?> getById(int id) async {
    final schema = await _loadTransferSchema();
    final struct = buildTransferStruct(schema);
    final m = await fetchKgqlModelById(
      _client,
      modelTypeName: kTransferModelTypeName,
      id: id,
      struct: struct,
    );
    return m == null ? null : transferFromModel(m);
  }

  @override
  Future<int> upsert(TransferUpsert payload) async {
    final req = _transferRequest(payload);
    return setKgqlModel(_client, req);
  }

  @override
  Future<void> deleteById(int id) async {
    await setKgqlModel(_client, SetModelRequest(id: id, delete: true));
  }

  @override
  Future<void> linkTransferToTellerTimeline({
    required int transferId,
    required String tellerEventId,
    required DateTime tellerEventTime,
  }) async {
    await linkModelToTimelineEvent(
      _client,
      modelId: transferId,
      eventTime: tellerEventTime,
      eventId: tellerEventId,
    );
  }

  @override
  Future<ExpenseSummary> listSummary({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final transfers = await list(rangeStart: rangeStart, rangeEnd: rangeEnd);
    final schema = await _loadTransferSchema();
    final key = schema.attributes
        ?.where((a) => a.valueType == 'number' && (a.key ?? '').isNotEmpty)
        .map((a) => a.key!)
        .firstOrNull;
    num? sum;
    if (key != null) {
      sum = 0;
      for (final m in transfers) {
        final raw = m.attributes?[key];
        final n = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
        sum = sum! + n;
      }
    }
    return ExpenseSummary(count: transfers.length, sumTotal: sum);
  }
}

extension _FirstOrNullT<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
