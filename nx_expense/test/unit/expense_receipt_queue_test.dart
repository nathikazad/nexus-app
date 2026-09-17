import 'dart:io';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_db/app_reads.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';
import 'package:nx_expense/data/sync/expense_receipts.dart';
import 'package:nx_expense/data/sync/expense_store.dart';
import 'package:nx_expense/data/sync/expense_transport.dart';

void main() {
  test(
    'receipt bytes survive restart and upload with the same operation ID',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'expense-receipt-',
      );
      FileLibrary open() => FileLibrary(
        database: LibraryDatabase(
          NativeDatabase(File('${directory.path}/db.sqlite')),
        ),
        files: DirectoryContentFiles(Directory('${directory.path}/json')),
      );
      var library = open();
      final files = DirectoryBinaryContentFiles('${directory.path}/binary');
      const account = AccountIdentity(
        serverId: 'test',
        userId: '1',
        domainId: 2,
        application: 'expense',
      );
      var store = ExpenseStore(library, account);
      var uploads = 0;
      final remote = ExpenseTransport(
        AppReads(
          MockClient((request) async {
            uploads++;
            expect(request.body, contains('receipt.jpg'));
            return http.Response(
              jsonEncode({
                'status': 'applied',
                'id': -1,
                'entity': {
                  'id': -1,
                  'kind': 'event',
                  'event_id': '99',
                  'event_time': '2026-09-16T12:00:00',
                  'event_type': 'image',
                  'payload': {'path': 'receipt.jpg'},
                },
              }),
              200,
            );
          }),
          Uri.parse('https://example.test'),
          'expense',
          cacheResponses: false,
        ),
      );
      final result =
          await ExpenseReceipts(remote, 2, store: store, files: files).add(
            bytes: [1, 2, 3, 4],
            filename: 'receipt.jpg',
            contentType: 'image/jpeg',
            capturedAt: DateTime(2026, 9, 16, 12),
            timezone: 'America/Los_Angeles',
          );
      expect(result['status'], 'queued');
      expect(uploads, 0);
      final operation = (await store.pendingMutations()).single.operationId;
      await library.close();
      library = open();
      store = ExpenseStore(library, account);
      final pending = (await store.pendingMutations()).single;
      expect(pending.operationId, operation);
      final receipt = await ExpenseReceiptHandler(
        store,
        remote,
        files,
      ).execute(pending);
      await store.complete(receipt);
      expect(uploads, 1);
      expect(await store.pendingMutations(), isEmpty);
      expect((await store.all()).single['event_id'], '99');
      await library.close();
      await remote.reads.close();
      await directory.delete(recursive: true);
    },
  );
}
