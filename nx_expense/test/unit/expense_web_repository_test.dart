import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_db/app_reads.dart';
import 'package:nx_expense/data/sync/expense_data_repository.dart';
import 'package:nx_expense/data/sync/expense_transport.dart';

void main() {
  test(
    'web pages use remote reads and memory caching with no persistent store',
    () async {
      var requests = 0;
      final reads = AppReads(
        MockClient((request) async {
          requests++;
          expect(request.url.queryParameters['kind'], 'expenses');
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 1, 'name': 'Groceries'},
              ],
              'next_cursor': null,
            }),
            200,
          );
        }),
        Uri.parse('https://example.test'),
        'expense',
      );
      final repository = ExpenseDataRepository(
        reads: reads,
        remote: ExpenseTransport(reads),
        domainId: 7,
      );
      expect(repository.store, isNull);
      expect((await repository.list('Expense')).single['name'], 'Groceries');
      await repository.list('Expense');
      expect(requests, 1);
      reads.invalidate();
      await repository.list('Expense');
      expect(requests, 2);
      await reads.close();
    },
  );
  test(
    'web retry after an uncertain response reuses the operation ID',
    () async {
      final ids = <String>[];
      final reads = AppReads(
        MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          ids.add(body['operation_id'] as String);
          expect(body['domain_id'], 7);
          if (ids.length == 1) return http.Response('unavailable', 503);
          return http.Response(
            jsonEncode({
              'status': 'applied',
              'id': 42,
              'entity': {'id': 42},
            }),
            200,
          );
        }),
        Uri.parse('https://example.test'),
        'expense',
      );
      final repository = ExpenseDataRepository(
        reads: reads,
        remote: ExpenseTransport(reads),
        domainId: 7,
      );
      Future<int> save() => repository.save(
        {'model_type': 'Expense', 'name': 'Groceries'},
        optimistic: {'name': 'Groceries'},
        expectedRevision: null,
      );
      await expectLater(save(), throwsException);
      expect(await save(), 42);
      expect(ids[0], ids[1]);
      expect(await save(), 42);
      expect(ids[2], isNot(ids[1]));
      await reads.close();
    },
  );
}
