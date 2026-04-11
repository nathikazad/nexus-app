import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/nx_db.dart';

import '../app_theme.dart';
import '../expense_schema.dart';
import '../providers/expense_providers.dart';
import '../reference_layout.dart';

/// Reference Screen 8: hierarchical tag browser (accordion).
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
            backgroundColor: Colors.white,
            appBar: AppBar(title: const Text('Not found')),
            body: const Center(child: Text('Tag system not found')),
          );
        }
        final displayTitle = ts.name.toLowerCase() == 'category' ? 'Categories' : ts.name;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 22),
              onPressed: () => context.pop(),
            ),
            centerTitle: true,
            title: Text(displayTitle, style: refAppBarTitleBase()),
            actions: [
              IconButton(
                icon: const Icon(Icons.search, color: AppColors.slate400, size: 22),
                onPressed: () {},
              ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: AppColors.slate100),
            ),
          ),
          body: ts.isHierarchical
              ? ListView(
                  children: [
                    for (final n in ts.nodes)
                      _HierNode(ref: ref, node: n, systemName: ts.name, depth: 0),
                  ],
                )
              : ListView(
                  children: [
                    for (final n in ts.nodes)
                      Material(
                        color: Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: RefLayout.px5, vertical: 8),
                          title: Text(
                            n.name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate900,
                            ),
                          ),
                          trailing: Text(
                            '—',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400),
                          ),
                          onTap: () => _applyFilter(context, ref, ts.name, n.name),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  void _applyFilter(BuildContext context, WidgetRef ref, String system, String node) {
    ref.read(expenseListFilterProvider.notifier).setFilter(ExpenseFilter(
          tagFilters: [
            {
              'system': system,
              'node': node,
              'include_descendants': true,
            },
          ],
        ));
    ref.invalidate(expenseListForUiProvider);
    context.go('/expenses');
  }
}

class _HierNode extends StatelessWidget {
  const _HierNode({
    required this.ref,
    required this.node,
    required this.systemName,
    required this.depth,
  });

  final WidgetRef ref;
  final TagNode node;
  final String systemName;
  final int depth;

  void _apply(BuildContext context) {
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
  }

  @override
  Widget build(BuildContext context) {
    final ch = node.children ?? const <TagNode>[];
    if (ch.isEmpty) {
      return Material(
        color: Colors.white,
        child: ListTile(
          contentPadding: EdgeInsets.only(left: 20.0 + depth * 16, right: RefLayout.px5, top: 4, bottom: 4),
          title: Text(
            node.name,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.slate700,
            ),
          ),
          trailing: Text(
            '—',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400),
          ),
          onTap: () => _apply(context),
        ),
      );
    }
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: AppColors.slate100),
      child: ExpansionTile(
        // Unique key so expand/collapse state survives scroll; required for ExpansionTile in ListView.
        key: PageStorageKey<String>('tag_browser_${systemName}_${node.name}_$depth'),
        tilePadding: EdgeInsets.only(left: 20.0 + depth * 8, right: RefLayout.px5),
        childrenPadding: EdgeInsets.zero,
        // Do not set custom leading/trailing: they replace the default expand icon and can break taps
        // on some Flutter versions (Expansible + ListTile header).
        title: Text(
          node.name,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate900),
        ),
        subtitle: Text(
          '${ch.length} items',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate400),
        ),
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        children: [
          ColoredBox(
            color: AppColors.slate50.withValues(alpha: 0.5),
            child: Column(
              children: [
                for (final c in ch)
                  _HierNode(ref: ref, node: c, systemName: systemName, depth: depth + 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
