import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_expense/data/expense/expense_file_cache.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';

void main() {
  late Directory dir;
  late FileLibrary library;
  late DirectoryContentFiles files;
  late ExpenseFileCache cache;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nx-expense-files-');
    files = DirectoryContentFiles(Directory('${dir.path}/content'));
    library = FileLibrary(
      database: LibraryDatabase(
        NativeDatabase(File('${dir.path}/index.sqlite')),
      ),
      files: files,
    );
    cache = ExpenseFileCache(library);
  });
  tearDown(() async {
    await library.close();
    await dir.delete(recursive: true);
  });

  test(
    'only the exact downloaded query is available offline; empty is distinct from unknown',
    () async {
      final filter = <String, dynamic>{'month': '2026-01'};
      final struct = <String, dynamic>{'id': true, 'name': true};
      final original = Model.fromJson({
        'id': 1,
        'name': 'Coffee',
        'attributes': {'amount': -5},
      });
      await cache.models('Expense', filter, struct, () async => [original]);
      final rows = await cache.models(
        'Expense',
        filter,
        struct,
        () async => throw const SocketException('offline'),
      );
      expect(rows.single.name, 'Coffee');
      await expectLater(
        cache.models(
          'Expense',
          {'month': '2026-02'},
          struct,
          () async => throw const SocketException('offline'),
        ),
        throwsA(isA<SocketException>()),
      );
      await cache.models('Expense', filter, struct, () async => []);
      expect(
        await cache.models(
          'Expense',
          filter,
          struct,
          () async => throw const SocketException('offline'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'cached totals require zero body reads and are invalidated after mutations',
    () async {
      final filter = <String, dynamic>{'month': '2026-01'};
      final operation = <String, dynamic>{'metric': 'sum'};
      await cache.aggregate(
        filter,
        operation,
        () async => {'aggregated_value': 15},
      );
      expect(
        (await cache.aggregate(
          filter,
          operation,
          () async => throw const SocketException('offline'),
        ))['aggregated_value'],
        15,
      );
      expect(files.reads, 0);
      await cache.invalidate();
      await expectLater(
        cache.aggregate(
          filter,
          operation,
          () async => throw const SocketException('offline'),
        ),
        throwsA(isA<SocketException>()),
      );
    },
  );
}
