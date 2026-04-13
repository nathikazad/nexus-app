import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/expense_providers.dart';

/// Minimal screen that exercises schema + struct providers (Phase 3 shell).
class DebugExpenseScreen extends ConsumerWidget {
  const DebugExpenseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemaAsync = ref.watch(expenseSchemaProvider);
    final struct = ref.watch(expenseStructProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense (debug)'),
      ),
      body: schemaAsync.when(
        data: (mt) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            'ModelType: ${mt.name} (id=${mt.id})\n'
            'tag systems: ${mt.tagSystems?.length ?? 0}\n\n'
            'Struct keys:\n${struct.keys.toList()..sort()}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            'Error loading schema:\n$e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}
