import 'package:flutter/material.dart' hide Action;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/core/formatting/time_format.dart';
import 'package:nx_time/features/action_edit/action_category_option.dart';
import 'package:nx_time/features/action_edit/action_edit_providers.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/features/tasks/task_picker_page.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';
import 'package:nx_time/features/today/today_view_model.dart';
import 'package:nx_time/features/action_create/add_child_actions_page.dart';
import 'package:nx_time/features/action_edit/action_edit_view_model.dart';
import 'package:nx_time/features/action_edit/widgets/action_category_picker.dart';
import 'package:nx_time/features/action_edit/widgets/action_datetime_picker.dart';

enum ActionEditMode {
  create,
  edit,
}

/// Create or edit a logged Action via [ActionRepository] (KGQL by default).
class ActionEditPage extends ConsumerStatefulWidget {
  const ActionEditPage({
    super.key,
    this.mode = ActionEditMode.create,
    this.initial,
    this.parentActionId,
    this.prefillStart,
    this.prefillEnd,
    this.prefillCategory,
  });

  final ActionEditMode mode;
  final Action? initial;

  /// When set, create links the new action under this parent via `action_action`.
  final int? parentActionId;

  final DateTime? prefillStart;
  final DateTime? prefillEnd;
  final ActionCategoryOption? prefillCategory;

  @override
  ConsumerState<ActionEditPage> createState() => _ActionEditPageState();
}

class _ActionEditPageState extends ConsumerState<ActionEditPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  ActionCategoryOption? _categoryCreate;
  late ActionCategoryOption _categoryEdit;
  late DateTime _start;
  late DateTime _end;
  bool _saving = false;

  bool get _isCreate => widget.mode == ActionEditMode.create;

  @override
  void initState() {
    super.initState();
    if (_isCreate) {
      _nameController = TextEditingController();
      _notesController = TextEditingController();
      final n = DateTime.now();
      final ps = widget.prefillStart;
      final pe = widget.prefillEnd;
      if (ps != null && pe != null) {
        _start = ps;
        _end = pe;
      } else {
        _start = n;
        _end = n;
      }
      if (widget.prefillCategory != null) {
        _categoryCreate = widget.prefillCategory;
      }
    } else {
      final a = widget.initial!;
      _nameController = TextEditingController(text: a.name);
      _notesController = TextEditingController(text: a.description ?? '');
      _categoryEdit = ActionCategoryOption.fromAction(a);
      _start = a.startTime ?? DateTime.now();
      _end = a.endTime ?? _start.add(const Duration(hours: 1));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    try {
      final options = await ref.read(actionCategoryOptionsProvider.future);
      if (!mounted) return;
      if (options.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No action types available')),
        );
        return;
      }
      final choice = await showActionCategoryPicker(
        context,
        categories: options,
        selected: _isCreate ? _categoryCreate : _categoryEdit,
      );
      if (choice != null && mounted) {
        setState(() {
          if (_isCreate) {
            _categoryCreate = choice;
          } else {
            _categoryEdit = choice;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load categories: $e')),
        );
      }
    }
  }

  Future<void> _pickStart() async {
    final t = await showActionDateTimePicker(
      context,
      initialDateTime: _start,
      title: 'Start (date & time)',
    );
    if (t != null && mounted) {
      setState(() => _start = t);
    }
  }

  Future<void> _pickEnd() async {
    final t = await showActionDateTimePicker(
      context,
      initialDateTime: _end,
      title: 'End (date & time)',
    );
    if (t != null && mounted) {
      setState(() => _end = t);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final err = ActionEditViewModel.snackbarErrorForSave(
      nameTrimmed: name,
      isCreate: _isCreate,
      categoryCreate: _categoryCreate,
    );
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(actionRepositoryProvider);
      final start = _start;
      var end = _end;
      end = ActionEditViewModel.normalizeEndAfterStart(start, end);
      final notesRaw = _notesController.text.trim();
      final notes = notesRaw.isEmpty ? null : notesRaw;

      if (_isCreate) {
        final cat = _categoryCreate!;
        final action = ActionEditViewModel.buildCreateAction(
          name: name,
          notes: notes,
          category: cat,
          start: start,
          end: end,
        );
        final newId = await repo.create(
          action,
          cat.name,
          parentActionId: widget.parentActionId,
        );
        ref.invalidate(todaySnapshotProvider);
        if (!mounted) return;
        Navigator.of(context).pop();
        if (widget.parentActionId != null) {
          return;
        }
        final created = Action(
          id: newId,
          name: action.name,
          description: action.description,
          modelTypeId: action.modelTypeId,
          modelTypeName: cat.name,
          startTime: action.startTime,
          endTime: action.endTime,
        );
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => AddChildActionsPage(parent: created),
          ),
        );
        return;
      } else {
        final a = widget.initial!;
        final cat = _categoryEdit;
        final action = ActionEditViewModel.buildUpdateAction(
          initial: a,
          name: name,
          notes: notes,
          category: cat,
          start: start,
          end: end,
        );
        await repo.update(
          action,
          modelTypeNameIfChanged:
              ActionEditViewModel.modelTypeNameIfChanged(a, cat),
        );
      }

      ref.invalidate(todaySnapshotProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!_isCreate) {
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      debugPrint('ActionEditPage._save: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (_isCreate) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this action?'),
        content: const Text('This removes the time block from your log.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(actionRepositoryProvider).delete(widget.initial!.id);
      ref.invalidate(todaySnapshotProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('ActionEditPage._confirmDelete: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isCreate ? 'Add time block' : 'Edit action';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.sky600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _saving ? AppColors.slate300 : AppColors.sky600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 12, 20, _isCreate ? 32 : 24),
                children: [
                  const Text(
                    'Name',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _OutlineField(
                    child: TextField(
                      controller: _nameController,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: _isCreate
                            ? 'e.g., Evening walk, Reading…'
                            : 'Action name',
                        hintStyle: const TextStyle(color: AppColors.slate400),
                      ),
                      style: const TextStyle(fontSize: 14, color: AppColors.slate900),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Type',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _saving ? null : _pickCategory,
                      borderRadius: BorderRadius.circular(10),
                      child: _OutlineField(
                        child: _isCreate
                            ? (_categoryCreate == null
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Select type',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.slate400,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '▶',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.slate400,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: _categoryCreate!.dotColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _categoryCreate!.label,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.slate900,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '▶',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.slate400,
                                        ),
                                      ),
                                    ],
                                  ))
                            : Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _categoryEdit.dotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _categoryEdit.label,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.slate900,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Change ▶',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.slate400,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Start',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.slate900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _saving ? null : _pickStart,
                                borderRadius: BorderRadius.circular(10),
                                child: _OutlineField(
                                  child: Center(
                                    child: Text(
                                      formatActionDateTimeLine(_start),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.slate900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'End',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.slate900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _saving ? null : _pickEnd,
                                borderRadius: BorderRadius.circular(10),
                                child: _OutlineField(
                                  child: Center(
                                    child: Text(
                                      formatActionDateTimeLine(_end),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.slate900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.slate100.withValues(alpha: 0.9)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Associated tasks',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slate900,
                        ),
                      ),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                final picked = await Navigator.of(context)
                                    .push<Set<int>?>(
                                  MaterialPageRoute(
                                    builder: (_) => const TaskPickerPage(),
                                  ),
                                );
                                if (!mounted) return;
                                if (picked != null && picked.isNotEmpty) {
                                  final repo = ref.read(taskRepositoryProvider);
                                  await pinTaskIdsToCalendarDay(
                                    repo,
                                    picked,
                                    DateTime.now(),
                                  );
                                  ref.invalidate(tasksForTodayProvider);
                                  ref.invalidate(allTasksProvider);
                                }
                                ref.invalidate(todaySnapshotProvider);
                              },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '+ Add task',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.sky600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'No tasks linked yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.slate400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.slate100.withValues(alpha: 0.9)),
                  const SizedBox(height: 12),
                  const Text(
                    'Notes',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _OutlineField(
                    alignment: Alignment.topLeft,
                    minHeight: 64,
                    child: TextField(
                      controller: _notesController,
                      enabled: !_saving,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Optional — add notes…',
                        hintStyle: TextStyle(color: AppColors.slate400),
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.slate700,
                        height: 1.5,
                      ),
                    ),
                  ),
                  if (!_isCreate) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: AppColors.slate100.withValues(alpha: 0.9)),
                    const SizedBox(height: 16),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _saving ? null : _confirmDelete,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFFECACA)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Delete action',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineField extends StatelessWidget {
  const _OutlineField({
    required this.child,
    this.alignment = Alignment.centerLeft,
    this.minHeight = 0,
  });

  final Widget child;
  final AlignmentGeometry alignment;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: BoxConstraints(minHeight: minHeight > 0 ? minHeight : 42),
      alignment: alignment,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}
