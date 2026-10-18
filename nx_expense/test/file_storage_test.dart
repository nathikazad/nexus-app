import 'dart:io';
import 'dart:async';
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
    cache = ExpenseFileCache(library, cacheFirst: false);
  });
  tearDown(() async {
    await library.close();
    await dir.delete(recursive: true);
  });

  test(
    'cached rows return before a stalled refresh and publish fresh data later',
    () async {
      final filter = <String, dynamic>{'month': '2026-10'};
      final struct = <String, dynamic>{'id': true, 'name': true};
      await cache.models(
        'Expense',
        filter,
        struct,
        () async => [
          Model.fromJson({'id': 1, 'name': 'Cached'}),
        ],
      );
      final remote = Completer<List<Model>>();
      final changed = Completer<void>();
      final fast = ExpenseFileCache(
        library,
        onChanged: () => changed.complete(),
      );
      final rows = await fast
          .models('Expense', filter, struct, () => remote.future)
          .timeout(const Duration(milliseconds: 500));
      expect(rows.single.name, 'Cached');
      expect(remote.isCompleted, false);
      remote.complete([
        Model.fromJson({'id': 1, 'name': 'Fresh'}),
      ]);
      await changed.future.timeout(const Duration(seconds: 2));
      expect(
        (await fast.models(
          'Expense',
          filter,
          struct,
          () => throw StateError('should not wait'),
        )).single.name,
        'Fresh',
      );
      await fast.close();
    },
  );

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
