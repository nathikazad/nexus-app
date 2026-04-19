import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/expense/expense_bulk_mutations.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';
import 'package:nx_expense/features/expense/expense_list_view_model.dart';
import 'widgets/relation_picker.dart';
import 'widgets/tag_picker.dart';

/// Per-model failures from bulk update (id → error message).
class BulkApplyResult {
  BulkApplyResult({required this.failures});

  final Map<int, String> failures;

  bool get hasFailures => failures.isNotEmpty;
}

/// Applies tag assignment for a single tag [systemName] to each expense [ids].
/// Only that system is sent; other tag systems are unchanged (server merge).
Future<BulkApplyResult> bulkApplyTag({
  required WidgetRef ref,
  required List<int> ids,
  required String systemName,
  required List<String> nodes,
}) async {
  final r = await bulkApplyExpenseTags(
    container: ref.container,
    ids: ids,
    systemName: systemName,
    nodes: nodes,
  );
  return BulkApplyResult(failures: r.failures);
}

/// Sets relation [targetTypeName] links to [linkIds] for each expense [ids].
Future<BulkApplyResult> bulkApplyRelation({
  required WidgetRef ref,
  required List<int> ids,
  required String targetTypeName,
  required List<int> linkIds,
}) async {
  final r = await bulkApplyExpenseRelations(
    container: ref.container,
    ids: ids,
    targetTypeName: targetTypeName,
    linkIds: linkIds,
  );
  return BulkApplyResult(failures: r.failures);
}

Future<void> showBulkApplyMenu(
  BuildContext context,
  WidgetRef ref,
  ModelTypeView schema,
) async {
  final n = ref.read(expenseListSelectedIdsProvider).length;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  RefLayout.px5,
                  8,
                  RefLayout.px5,
                  4,
                ),
                child: Text(
                  'Apply to $n expenses',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate400,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  RefLayout.px5,
                  0,
                  RefLayout.px5,
                  8,
                ),
                child: Text(
                  'Choose what to set',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.label_outline,
                  color: AppColors.teal600,
                ),
                title: const Text('Tag'),
                subtitle: Text(
                  'Category, priority, or any tag system',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.slate500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  bulkPickTag(context, ref, schema);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.business_outlined,
                  color: AppColors.slate600,
                ),
                title: const Text('Company or project'),
                subtitle: Text(
                  'Link to an existing record',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.slate500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  bulkPickRelation(context, ref, schema);
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune, color: AppColors.slate600),
                title: const Text('Attribute'),
                subtitle: Text(
                  'Pick a tag system, then a value',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.slate500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  bulkPickTag(context, ref, schema);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> bulkPickTag(
  BuildContext context,
  WidgetRef ref,
  ModelTypeView schema,
) async {
  final systems = schema.tagSystems;
  if (systems.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No tag systems defined')));
    }
    return;
  }

  TagSystemView? pick;
  if (systems.length == 1) {
    pick = systems.first;
  } else {
    pick = await showModalBottomSheet<TagSystemView>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final ts in systems)
              ListTile(
                title: Text(ts.name),
                onTap: () => Navigator.pop(ctx, ts),
              ),
          ],
        ),
      ),
    );
  }
  if (pick == null || !context.mounted) return;

  final nodes = await showTagPickerSheet(
    context,
    system: pick,
    initial: const [],
  );
  if (nodes == null || !context.mounted) return;

  final ids = ref.read(expenseListSelectedIdsProvider).toList();
  if (ids.isEmpty) return;

  final messenger = ScaffoldMessenger.of(context);

  final result = await bulkApplyTag(
    ref: ref,
    ids: ids,
    systemName: pick.name,
    nodes: nodes,
  );

  if (!context.mounted) return;

  for (final id in ids) {
    ref.invalidate(expenseDetailProvider(id));
  }
  invalidateExpenseListCache(ref);
  ref.read(expenseListSelectionModeProvider.notifier).setSelecting(false);

  if (result.hasFailures) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Updated with ${result.failures.length} error(s). ${result.failures.values.first}',
        ),
      ),
    );
  } else {
    messenger.showSnackBar(const SnackBar(content: Text('Tags updated')));
  }
}

Future<void> bulkPickRelation(
  BuildContext context,
  WidgetRef ref,
  ModelTypeView schema,
) async {
  final relNames = allRelationTargetTypeNames(schema).toList();
  if (relNames.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No relation types defined')),
      );
    }
    return;
  }

  String? target;
  if (relNames.length == 1) {
    target = relNames.first;
  } else {
    target = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final n in relNames)
              ListTile(title: Text(n), onTap: () => Navigator.pop(ctx, n)),
          ],
        ),
      ),
    );
  }
  if (target == null || !context.mounted) return;

  final res = await showRelationPickerSheet(
    context,
    targetModelTypeName: target,
    initialIds: const [],
    allowMultiple: false,
  );
  if (res == null || !context.mounted) return;
  if (res is RelationPickCreate) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Creating new records in bulk is not supported'),
      ),
    );
    return;
  }
  final link = res as RelationPickLink;
  final ids = ref.read(expenseListSelectedIdsProvider).toList();
  if (ids.isEmpty) return;

  final messenger = ScaffoldMessenger.of(context);

  final result = await bulkApplyRelation(
    ref: ref,
    ids: ids,
    targetTypeName: target,
    linkIds: link.ids,
  );

  if (!context.mounted) return;

  for (final id in ids) {
    ref.invalidate(expenseDetailProvider(id));
  }
  ref.invalidate(relatedModelsProvider(target));
  invalidateExpenseListCache(ref);
  ref.read(expenseListSelectionModeProvider.notifier).setSelecting(false);

  if (result.hasFailures) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Updated with ${result.failures.length} error(s). ${result.failures.values.first}',
        ),
      ),
    );
  } else {
    messenger.showSnackBar(const SnackBar(content: Text('Relations updated')));
  }
}
