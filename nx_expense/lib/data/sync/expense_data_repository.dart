import 'dart:math';
import 'dart:convert';
import 'package:nx_db/app_reads.dart';
import 'expense_store.dart';
import 'expense_transport.dart';

String expenseOperationId() {
  final random = Random.secure();
  return List.generate(
    24,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class ExpenseConflict implements Exception {
  ExpenseConflict(this.local, this.remote);
  final Map<String, dynamic> local, remote;
  @override
  String toString() =>
      'This expense changed on another device. Review both versions.';
}

/// Identical application API; nullable store selects remote-only browser reads.
/// Construct the store lazily through AppDataPolicy, never inside this class.
class ExpenseDataRepository {
  ExpenseDataRepository({
    required this.reads,
    required this.remote,
    required this.domainId,
    this.store,
    this.onPending,
    this.onChanged,
  });
  final AppReads reads;
  final ExpenseTransport remote;
  final int domainId;
  final ExpenseStore? store;
  final void Function()? onPending, onChanged;
  final Map<String, String> _webOperations = {};
  static const kinds = {
    'Expense': 'expenses',
    'Order': 'orders',
    'Product': 'products',
    'Company': 'companies',
    'Person': 'persons',
    'Goal': 'budgets',
  };

  Future<List<Map<String, dynamic>>> list(String family) async {
    final native = store;
    if (native == null) return reads.items(query: {'kind': kinds[family]!});
    final rows = (await native.all())
        .where((e) => e['model_type']?['name'] == family)
        .toList();
    if (await isComplete()) return rows;
    final live = await reads.items(query: {'kind': kinds[family]!});
    await native.acceptLive(live);
    return (await native.all())
        .where((e) => e['model_type']?['name'] == family)
        .toList();
  }

  Future<List<Map<String, dynamic>>> events() async {
    try {
      return await reads.items(query: {'kind': 'images'});
    } on AppReadException catch (error) {
      if (error.statusCode < 500) rethrow;
      if (store == null || !await isComplete()) rethrow;
    } catch (_) {
      if (store == null || !await isComplete()) rethrow;
    }
    return (await store!.all()).where((r) => r['kind'] == 'event').toList();
  }

  /// Visible reads are live; the independent snapshot is the native fallback.
  Future<Map<String, dynamic>?> visible(int id) async {
    try {
      return await reads.read('$id');
    } on AppReadException catch (error) {
      if (error.statusCode == 404) return null;
      if (error.statusCode < 500) rethrow;
      if (store == null) rethrow;
      return get(id);
    } catch (_) {
      if (store == null) rethrow;
      return get(id);
    }
  }

  Future<bool> isComplete() async {
    if (store == null) return true;
    return await store!.library.read('expense_state', 'coverage') != null;
  }

  Future<Map<String, dynamic>?> get(int id) async {
    if (store case final native?) {
      if ((await native.library.metadata(
            'expense',
            await native.localId('$id'),
          ))?.deleted ==
          true) {
        return null;
      }
      final local = await native.get('$id');
      if (local != null) return local;
      if (await isComplete()) return null;
    }
    try {
      final value = await reads.read('$id');
      await store?.acceptLive([value]);
      return value;
    } on AppReadException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<int> save(
    Map<String, dynamic> command, {
    required Map<String, dynamic> optimistic,
    required String? expectedRevision,
  }) async {
    final key = jsonEncode([command, expectedRevision]);
    final operationId = store == null
        ? _webOperations.putIfAbsent(key, expenseOperationId)
        : expenseOperationId();
    if (store case final native?) {
      final requested = command['id'] as int?;
      // UI routes use positive integers. Temporary IDs live outside PostgreSQL's
      // integer model range and are never sent to the server.
      final localId = requested == null
          ? '${DateTime.now().microsecondsSinceEpoch}'
          : await native.localId('$requested');
      await native.enqueue(
        operationId: operationId,
        localId: localId,
        command: command,
        optimistic: {...optimistic, 'id': requested ?? int.parse(localId)},
        now: DateTime.now().toUtc(),
        expectedRevision: expectedRevision,
      );
      onChanged?.call();
      onPending?.call();
      return requested ?? int.parse(localId);
    }
    final result = await remote.execute({
      'operation_id': operationId,
      'data': command,
      'expected_revision': expectedRevision,
      'domain_id': domainId,
    });
    _webOperations.remove(key);
    if (result['status'] == 'conflict') {
      throw ExpenseConflict(
        optimistic,
        Map<String, dynamic>.from(result['entity'] as Map),
      );
    }
    onChanged?.call();
    return result['id'] as int;
  }
}
