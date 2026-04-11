import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/nx_db.dart';

import '../expense_schema.dart';
import '../providers/expense_providers.dart';

class TagSystemsScreen extends ConsumerWidget {
  const TagSystemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemaAsync = ref.watch(expenseSchemaProvider);

    return schemaAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (schema) {
        final systems = schema.tagSystems ?? const <TagSystem>[];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tag systems'),
          ),
          body: ListView.builder(
            itemCount: systems.length,
            itemBuilder: (context, i) {
              final ts = systems[i];
              return ListTile(
                title: Text(ts.name),
                subtitle: Text(
                  '${ts.selectionMode} · ${ts.isHierarchical ? "tree" : "flat"} · ${countTagNodes(ts)} nodes',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/tag-system/form/${ts.id}'),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.push('/tag-system/form'),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
