import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_expense/data/suggestion/suggestion_api.dart';
import 'package:nx_expense/domain/suggestion/expense_suggestion.dart';

void main() {
  group('ExpenseSuggestion', () {
    test('parses the Expense to Product to Company graph', () {
      final suggestion = ExpenseSuggestion.fromJson(_suggestionRow());

      expect(suggestion.id, 26);
      expect(suggestion.bank.source, 'teller');
      expect(suggestion.bank.amount, -31.49);
      expect(suggestion.provider?.source, 'amazon');
      expect(suggestion.provider?.orderIds, ['113-1234567-1234567']);
      expect(suggestion.expense.id, 2669);
      expect(suggestion.expense.name, 'Raspberry Pi base board');
      expect(suggestion.createsExpense, isFalse);
      expect(suggestion.tags.single.label, 'Shopping / Electronics');
      expect(suggestion.products.single.name, 'Waveshare CM5 Mini Base Board');
      expect(suggestion.products.single.price, 28.99);
      expect(suggestion.products.single.quantity, 1);
      expect(
        suggestion.products.single.imageUrl,
        '/amazon/item_thumbnails/1/abc123.jpg',
      );
      expect(suggestion.products.single.maker?.name, 'Waveshare');
      expect(suggestion.products.single.maker?.createsCompany, isTrue);
      expect(suggestion.changes.first.field, 'Name');
      expect(suggestion.changes.first.before, 'Amazon');
      expect(suggestion.changes.first.after, 'Raspberry Pi base board');
    });

    test('uses existing expense evidence when proposal name is null', () {
      final row = _suggestionRow();
      final model = row['content']['proposal']['model'] as Map<String, dynamic>;
      model['name'] = null;

      final suggestion = ExpenseSuggestion.fromJson(row);

      expect(suggestion.expense.name, 'Raspberry Pi base board');
    });

    test('drops external and traversal-style Product images', () {
      for (final unsafe in [
        'https://m.media-amazon.com/image.jpg',
        '/amazon/item_thumbnails/1/../secret.jpg',
        '/amazon/item_thumbnails/1/image.svg',
      ]) {
        final row = _suggestionRow();
        final product = _productTarget(row);
        (product['attributes'] as List).first['value'] = unsafe;

        expect(
          ExpenseSuggestion.fromJson(row).products.single.imageUrl,
          isNull,
        );
      }
    });
  });

  group('suggestion HTTP API', () {
    test('loads grouped open suggestions', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/suggestions');
        expect(request.url.queryParameters['status'], 'open');
        expect(request.url.queryParameters['kind'], 'transaction_expense');
        expect(request.headers['x-user-id'], '1');
        return http.Response(
          jsonEncode({
            'ok': true,
            'count': 1,
            'cases': [
              {
                'case_key': 'transaction-expense:teller:2207',
                'suggestions': [_suggestionRow()],
              },
            ],
          }),
          200,
        );
      });

      final result = await fetchExpenseSuggestions(
        imageBaseUrl: 'http://10.0.0.156:8001/',
        userId: '1',
        httpClient: client,
      );

      expect(result.single.id, 26);
    });

    test('accepts and rejects through distinct action routes', () async {
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        expect(request.method, 'POST');
        expect(request.headers['x-user-id'], '1');
        return http.Response('{"ok":true}', 200);
      });

      await decideExpenseSuggestion(
        imageBaseUrl: 'http://10.0.0.156:8001',
        userId: '1',
        suggestionId: 26,
        accept: true,
        httpClient: client,
      );
      await decideExpenseSuggestion(
        imageBaseUrl: 'http://10.0.0.156:8001',
        userId: '1',
        suggestionId: 27,
        accept: false,
        httpClient: client,
      );

      expect(paths, ['/suggestions/26/accept', '/suggestions/27/reject']);
    });

    test('requests revision with a JSON note', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/suggestions/26/revise');
        expect(request.headers['content-type'], 'application/json');
        expect(jsonDecode(request.body), {'note': 'Use Electronics'});
        return http.Response('{"ok":true}', 200);
      });

      await reviseExpenseSuggestion(
        imageBaseUrl: 'http://10.0.0.156:8001',
        userId: '1',
        suggestionId: 26,
        note: 'Use Electronics',
        httpClient: client,
      );
    });

    test('surfaces stable server errors', () async {
      final client = MockClient(
        (_) async => http.Response(
          '{"ok":false,"error":"stale_suggestion","message":"Evidence changed"}',
          409,
        ),
      );

      expect(
        () => decideExpenseSuggestion(
          imageBaseUrl: 'http://10.0.0.156:8001',
          userId: '1',
          suggestionId: 26,
          accept: true,
          httpClient: client,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => '$error',
            'message',
            contains('Evidence changed'),
          ),
        ),
      );
    });

    test('resolves thumbnail paths against the Nexus HTTP host', () {
      expect(
        resolveSuggestionAssetUrl(
          'http://10.0.0.156:8001/',
          '/amazon/item_thumbnails/1/abc.jpg',
        ),
        'http://10.0.0.156:8001/amazon/item_thumbnails/1/abc.jpg',
      );
    });
  });
}

Map<String, dynamic> _suggestionRow() => {
  'id': 26,
  'case_key': 'transaction-expense:teller:2207',
  'status': 'open',
  'content': {
    'title': 'Link Amazon purchase',
    'reason': 'The amount and date match this Amazon order.',
    'evidence': {
      'bank': {
        'event_id': 2207,
        'source': 'teller',
        'event_type': 'teller_transaction',
        'date': '2026-01-30',
        'amount': -31.49,
        'description': 'AMAZON MKTPL',
        'account_last4': '8134',
      },
      'provider': {
        'event_id': 31049,
        'source': 'amazon',
        'event_type': 'transaction',
        'date': '2026-01-29',
        'amount': -31.49,
        'summary': 'Waveshare CM5 Mini Base Board',
        'evidence': {
          'order_ids': ['113-1234567-1234567'],
        },
      },
      'existing_expense': {
        'expense_id': 2669,
        'name': 'Raspberry Pi base board',
      },
    },
    'proposal': {
      'updates': {
        'name': {'from': 'Amazon', 'to': 'Raspberry Pi base board'},
        'attributes': [
          {'key': 'cost', 'from': 31.49, 'to': 28.99},
        ],
        'tags': {
          'add': [
            {
              'system': 'Spending Category',
              'path': ['Shopping', 'Electronics'],
            },
          ],
          'remove': <dynamic>[],
        },
      },
      'model': {
        'model_type': 'Expense',
        'id': 2669,
        'name': null,
        'attributes': <dynamic>[],
        'tags': [
          {
            'system': 'Spending Category',
            'path': ['Shopping', 'Electronics'],
          },
        ],
        'timeline_events': <dynamic>[],
        'relations': [
          {
            'relation_name': 'includes_product',
            'attributes': [
              {'key': 'price', 'value': 28.99},
              {'key': 'quantity', 'value': 1},
              {'key': 'unit', 'value': 'item'},
            ],
            'target': {
              'model_type': 'Product',
              'id': null,
              'name': 'Waveshare CM5 Mini Base Board',
              'attributes': [
                {
                  'key': 'image_url',
                  'value': '/amazon/item_thumbnails/1/abc123.jpg',
                },
              ],
              'tags': <dynamic>[],
              'timeline_events': <dynamic>[],
              'relations': [
                {
                  'relation_name': 'made_by',
                  'attributes': <dynamic>[],
                  'target': {
                    'model_type': 'Company',
                    'id': null,
                    'name': 'Waveshare',
                    'attributes': <dynamic>[],
                    'tags': <dynamic>[],
                    'timeline_events': <dynamic>[],
                    'relations': <dynamic>[],
                  },
                },
              ],
            },
          },
        ],
      },
    },
  },
};

Map<String, dynamic> _productTarget(Map<String, dynamic> row) {
  final content = row['content'] as Map<String, dynamic>;
  final proposal = content['proposal'] as Map<String, dynamic>;
  final model = proposal['model'] as Map<String, dynamic>;
  final relation = (model['relations'] as List).first as Map<String, dynamic>;
  return relation['target'] as Map<String, dynamic>;
}
