import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_db/app_reads.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/data/images/expense_images.dart';
import 'package:nx_expense/data/sync/expense_sync_providers.dart';
import 'package:nx_expense/data/sync/expense_data_repository.dart';
import 'package:nx_expense/data/sync/expense_transport.dart';

class _Graph extends Mock implements GraphQLClient {}

void main() {
  test(
    'server revision refreshes a mounted bill list and image details',
    () async {
      var version = 1;
      Map<String, dynamic> event() => {
        'id': -1,
        'kind': 'event',
        'source': 'expense_app',
        'event_type': 'image',
        'event_id': '123',
        'event_time': '2026-09-16T12:00:00',
        'payload': {
          'path': '/images/bill$version.pdf',
          'sha256': 'hash$version',
        },
        'links': [
          {'model_id': 71},
        ],
      };
      final reads = AppReads(
        MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.url.path.endsWith('/items')
                  ? {
                      'items': [event()],
                      'next_cursor': null,
                    }
                  : {
                      'id': 71,
                      'name': 'CarbonTree',
                      'model_type': {'name': 'Expense'},
                      'timeline_links': [
                        {...event(), 'id': '321'},
                      ],
                    },
            ),
            200,
          ),
        ),
        Uri.parse('https://nexus.example'),
        'expense',
      );
      final data = ExpenseDataRepository(
        reads: reads,
        remote: ExpenseTransport(reads),
        domainId: 2,
      );
      final container = ProviderContainer(
        overrides: [
          expenseDataRepositoryProvider.overrideWithValue(data),
          expenseGraphqlClientProvider.overrideWithValue(_Graph()),
        ],
      );
      final bills = container.listen(
        expenseTimelineLinksProvider(71),
        (_, _) {},
      );
      final imageKey = (id: '123', time: DateTime(2026, 9, 16, 12));
      final image = container.listen(expenseImageProvider(imageKey), (_, _) {});
      addTearDown(() async {
        bills.close();
        image.close();
        container.dispose();
        await reads.close();
      });
      expect(
        (await container.read(
          expenseTimelineLinksProvider(71).future,
        )).single.payload['sha256'],
        'hash1',
      );
      expect(
        (await container.read(expenseImageProvider(imageKey).future))!.filename,
        'bill1.pdf',
      );
      version = 2;
      reads.invalidate();
      container.read(expenseDataGenerationProvider.notifier).changed();
      expect(
        (await container.read(
          expenseTimelineLinksProvider(71).future,
        )).single.payload['sha256'],
        'hash2',
      );
      final updated = (await container.read(
        expenseImageProvider(imageKey).future,
      ))!;
      expect(updated.filename, 'bill2.pdf');
      expect(updated.hash, 'hash2');
      expect(updated.links.single.id, 71);
    },
  );
}
