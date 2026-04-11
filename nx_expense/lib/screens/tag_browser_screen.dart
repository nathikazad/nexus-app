import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/nx_db.dart';

import '../expense_schema.dart';
import '../providers/expense_providers.dart';

class TagBrowserScreen extends ConsumerWidget {
  const TagBrowserScreen({super.key, required this.systemName});

  final String systemName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemaAsync = ref.watch(expenseSchemaProvider);

    return schemaAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (schema) {
        final ts = tagSystemByName(schema, systemName);
        if (ts == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Tag system not found')),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(ts.name)),
          body: ts.isHierarchical
              ? ListView(
                  children: [
                    for (final n in ts.nodes) _HierNode(ref: ref, node: n, systemName: ts.name),
                  ],
                )
              : ListView(
                  children: [
                    for (final n in ts.nodes)
                      ListTile(
                        title: Text(n.name),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          context.pop();
                          ref.read(expenseListFilterProvider.notifier).setFilter(ExpenseFilter(
                            tagFilters: [
                              {
                                'system': ts.name,
                                'node': n.name,
                                'include_descendants': true,
                              },
                            ],
                          ));
                          ref.invalidate(expenseListForUiProvider);
                          context.go('/expenses');
                        },
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _HierNode extends StatelessWidget {
  const _HierNode({required this.ref, required this.node, required this.systemName});

  final WidgetRef ref;
  final TagNode node;
  final String systemName;

  @override
  Widget build(BuildContext context) {
    final ch = node.children ?? const <TagNode>[];
    if (ch.isEmpty) {
      return ListTile(
        title: Text(node.name),
        onTap: () {
          context.pop();
          ref.read(expenseListFilterProvider.notifier).setFilter(ExpenseFilter(
            tagFilters: [
              {
                'system': systemName,
                'node': node.name,
                'include_descendants': true,
              },
            ],
          ));
          ref.invalidate(expenseListForUiProvider);
          context.go('/expenses');
        },
      );
    }
    return ExpansionTile(
      title: Text(node.name),
      children: [
        for (final c in ch) _HierNode(ref: ref, node: c, systemName: systemName),
      ],
    );
  }
}
