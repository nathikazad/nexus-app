import 'package:flutter/material.dart' hide Action;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_time/core/theme/action_color_palette.dart';
import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/features/calendar/calendar_providers.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/features/action_create/add_child_actions_view_model.dart';
import 'package:nx_time/features/action_edit/action_category_option.dart';
import 'package:nx_time/features/action_edit/action_edit_page.dart';
import 'package:nx_time/features/action_edit/action_edit_providers.dart';
import 'package:nx_time/features/today/today_view_model.dart';

/// Post-save screen: add optional child actions under a parent, or tap Done.
class AddChildActionsPage extends ConsumerStatefulWidget {
  const AddChildActionsPage({
    super.key,
    required this.parent,
  });

  final Action parent;

  @override
  ConsumerState<AddChildActionsPage> createState() => _AddChildActionsPageState();
}

class _AddChildActionsPageState extends ConsumerState<AddChildActionsPage> {
  ParentActionKey get _key => (
        id: widget.parent.id,
        modelTypeName: widget.parent.modelTypeName ?? 'Action',
      );

  Future<void> _unlink(int childId) async {
    final repo = ref.read(actionRepositoryProvider);
    final fresh = await repo.getById(id: widget.parent.id, modelTypeName: _key.modelTypeName);
    if (fresh == null || !mounted) return;
    final rid = fresh.relationIdByChildId[childId];
    if (rid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find relation to remove')),
      );
      return;
    }
    try {
      await repo.unlinkChildAction(parentId: widget.parent.id, relationId: rid);
      ref.invalidate(todaySnapshotProvider);
      invalidateWeekActions(ref);
      ref.invalidate(parentActionForChildrenProvider(_key));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unlinked')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not unlink: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentAsync = ref.watch(parentActionForChildrenProvider(_key));
    final bar = barColorForModelTypeId(widget.parent.modelTypeId);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.sky600,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Action saved',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text(
                    widget.parent.name.isNotEmpty ? widget.parent.name : 'Action',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.slate100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: bar, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.parent.modelTypeName ?? 'Action',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.slate900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Add a child action?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final opts = ref.watch(actionCategoryOptionsProvider);
                      return opts.when(
                        data: (options) {
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final o in options)
                                _TypeChip(
                                  option: o,
                                  onTap: () {
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ActionEditPage(
                                          parentActionId: widget.parent.id,
                                          prefillStart: widget.parent.startTime,
                                          prefillEnd: widget.parent.endTime,
                                          prefillCategory: o,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (e, _) => Text(
                          'Could not load types: $e',
                          style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: AppColors.slate100),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Child actions',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slate900,
                        ),
                      ),
                      parentAsync.when(
                        data: (p) {
                          final n = p?.childActionIds.length ?? 0;
                          return Text(
                            '$n',
                            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  parentAsync.when(
                    data: (p) {
                      if (p == null || p.childActionIds.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'No child actions yet',
                              style: TextStyle(fontSize: 13, color: AppColors.slate400),
                            ),
                          ),
                        );
                      }
                      final snap = ref.watch(todaySnapshotProvider).asData?.value;
                      final byId = {
                        if (snap != null) for (final a in snap.dayActions) a.id: a,
                      };
                      return Column(
                        children: [
                          for (final cid in p.childActionIds)
                            _ChildRowTile(
                              childId: cid,
                              label: byId[cid]?.name.isNotEmpty == true
                                  ? byId[cid]!.name
                                  : (byId[cid]?.modelTypeName ?? 'Action #$cid'),
                              onUnlink: () => _unlink(cid),
                            ),
                        ],
                      );
                    },
                    loading: () => const Center(child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )),
                    error: (e, _) => Text('$e', style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.option, required this.onTap});

  final ActionCategoryOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.slate200),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: option.dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                option.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildRowTile extends StatelessWidget {
  const _ChildRowTile({
    required this.childId,
    required this.label,
    required this.onUnlink,
  });

  final int childId;
  final String label;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: AppColors.slate900),
              ),
            ),
            TextButton(
              onPressed: onUnlink,
              child: const Text(
                'Unlink',
                style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
