import 'dart:convert';

import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_expense/domain/expense/model_names.dart';
import 'package:nx_expense/domain/order/order.dart';

String _dateOnlyYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class KgqlOrderRepository {
  KgqlOrderRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadOrderSchema,
  }) : _client = client,
       _loadOrderSchema = loadOrderSchema;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadOrderSchema;

  Future<List<Order>> list({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final schema = await _loadOrderSchema();
    final rows = await fetchKgqlModels(
      _client,
      filter: {
        'model_type': kOrderModelTypeName,
        'filters': [
          {'key': 'order_date', 'op': '>=', 'value': _dateOnlyYmd(rangeStart)},
          {'key': 'order_date', 'op': '<=', 'value': _dateOnlyYmd(rangeEnd)},
        ],
      },
      struct: _orderStruct(schema),
    );
    return rows.map(orderFromModel).toList();
  }

  Future<Order?> getById(int id) async {
    final schema = await _loadOrderSchema();
    final m = await fetchKgqlModelById(
      _client,
      modelTypeName: kOrderModelTypeName,
      id: id,
      struct: _orderStruct(schema),
    );
    return m == null ? null : orderFromModel(m);
  }

  Map<String, dynamic> _orderStruct(ModelType schema) {
    final struct = buildKgqlStructFromSchema(schema);
    struct[kCompanyModelTypeName] = {'id': true, 'name': true};
    struct[kProductModelTypeName] = {'id': true, 'name': true};
    struct['relations'] = {
      'relation_id': true,
      'model_id': true,
      'model_type': true,
      'name': true,
      'description': true,
      'relation_attributes': {'key': true, 'value': true, 'value_type': true},
    };
    return struct;
  }
}

Order orderFromModel(Model m) {
  final attrs = m.attributes ?? const <String, dynamic>{};
  final companies = m.relations?[kCompanyModelTypeName] ?? const <Model>[];
  final products = m.relations?[kProductModelTypeName] ?? const <Model>[];
  final rels = m.relationsList ?? const <Relation>[];

  return Order(
    id: m.id,
    name: m.name,
    orderNumber: _stringAttr(attrs['order_number']) ?? m.name,
    orderDate: _stringAttr(attrs['order_date']) ?? m.createdAt ?? '',
    total: _numAttr(attrs['total']),
    companyName: companies.isEmpty ? null : companies.first.name,
    extras: _jsonMapAttr(attrs['extras']),
    products: [
      for (final product in products)
        _productFromModel(
          product,
          rels.where(
            (rel) =>
                rel.modelType == kProductModelTypeName &&
                rel.modelId == product.id,
          ),
        ),
    ],
  );
}

OrderProduct _productFromModel(Model product, Iterable<Relation> relations) {
  final rel = relations.isEmpty ? null : relations.first;
  final attrs = rel?.relationAttributes ?? const <String, dynamic>{};
  final extras = _jsonMapAttr(attrs['extras']);
  return OrderProduct(
    id: product.id,
    name: product.name,
    unitPrice: _numAttr(attrs['unit_price']),
    quantity: _numAttr(attrs['quantity']),
    unit: _stringAttr(attrs['unit']),
    lineTotal: _numAttr(extras?['line_total']),
    tax: _numAttr(extras?['tax']),
    status: _stringAttr(extras?['status']),
    deliveryDate: _stringAttr(extras?['delivery_date']),
    itemUrl: _stringAttr(extras?['item_url']),
    extras: extras,
  );
}

String? _stringAttr(dynamic raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  return text.isEmpty ? null : text;
}

num? _numAttr(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw;
  final cleaned = raw.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (cleaned.isEmpty) return null;
  return num.tryParse(cleaned);
}

Map<String, dynamic>? _jsonMapAttr(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }
  return null;
}
