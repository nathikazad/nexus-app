import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/nx_db.dart';

import '../expense_schema.dart';
import '../format.dart';
import '../providers/expense_providers.dart';
import '../widgets/expense_card.dart';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemaAsync = ref.watch(expenseSchemaProvider);
    final listAsync = ref.watch(expenseListForUiProvider);
    final summaryAsync = ref.watch(expenseSummaryProvider);
    final filter = ref.watch(expenseListFilterProvider);

    Future<void> refresh() async {
      ref.invalidate(expenseSchemaProvider);
      ref.invalidate(expenseListForUiProvider);
      ref.invalidate(expenseSummaryProvider);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/tag-systems'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: schemaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: SelectableText('Schema: $e')),
        data: (schema) {
          final chips = filterChipDescriptors(schema);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: summaryAsync.when(
                  data: (s) => Text(
                    s.sumTotal != null
                        ? '${s.count} expenses · ${formatMoney(s.sumTotal)} total'
                        : '${s.count} expenses',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  loading: () => const Text('…'),
                  error: (_, __) => const Text('—'),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: filter == null,
                        onSelected: (_) {
                          ref.read(expenseListFilterProvider.notifier).setFilter(null);
                          ref.invalidate(expenseListForUiProvider);
                        },
                      ),
                    ),
                    for (final d in chips)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(d.label),
                          selected: _chipSelected(filter, d),
                          onSelected: (_) {
                            if (d.nodeName == null) {
                              context.push('/tag-browser/${Uri.encodeComponent(d.systemName)}');
                            } else {
                              ref.read(expenseListFilterProvider.notifier).setFilter(ExpenseFilter(
                                tagFilters: [
                                  {
                                    'system': d.systemName,
                                    'node': d.nodeName,
                                    'include_descendants': true,
                                  },
                                ],
                              ));
                              ref.invalidate(expenseListForUiProvider);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: refresh,
                  child: listAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SelectableText('Error: $e'),
                        ),
                      ],
                    ),
                    data: (models) {
                      if (models.isEmpty) {
                        return ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('No expenses')),
                          ],
                        );
                      }
                      return ListView.builder(
                        itemCount: models.length,
                        itemBuilder: (context, i) {
                          final m = models[i];
                          return ExpenseCard(
                            model: m,
                            schema: schema,
                            onTap: () => context.push('/expense/${m.id}'),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/expense/form'),
        child: const Icon(Icons.add),
      ),
    );
  }

  bool _chipSelected(ExpenseFilter? f, FilterChipDescriptor d) {
    if (f?.tagFilters == null || f!.tagFilters!.isEmpty) return false;
    final tf = f.tagFilters!.first;
    return tf['system'] == d.systemName && tf['node'] == d.nodeName;
  }
}
