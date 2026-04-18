import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_db/src/models/requests/SetModelRequest.dart' as req;

import '../../app_theme.dart';
import '../../data/action_category_option.dart';
import '../../data/wall_clock_time.dart';
import '../../providers/action_category_providers.dart';
import '../../providers/time_providers.dart';
import '../tasks/task_picker_page.dart';
import 'activity_pickers.dart';

/// Edit a logged Action row (`set_kgql_models`). Reference: `partials/page-edit-activity.html`.
class EditActionPage extends ConsumerStatefulWidget {
  const EditActionPage({super.key, required this.model});

  final Model model;

  @override
  ConsumerState<EditActionPage> createState() => _EditActionPageState();
}

class _EditActionPageState extends ConsumerState<EditActionPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late ActionCategoryOption _category;
  late DateTime _start;
  late DateTime _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    _nameController = TextEditingController(text: m.name);
    _notesController = TextEditingController(text: m.description ?? '');
    _category = ActionCategoryOption.fromModel(m);
    final start = readWallClockDateTimeAttr(m, 'start_time');
    final end = readWallClockDateTimeAttr(m, 'end_time');
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    if (start != null) {
      _start = asStoredLocalWallClock(start);
    } else {
      _start = DateTime(today.year, today.month, today.day, 9, 0);
    }
    if (end != null) {
      _end = asStoredLocalWallClock(end);
    } else {
      _end = DateTime(today.year, today.month, today.day, 10, 0);
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
        selected: _category,
      );
      if (choice != null && mounted) {
        setState(() => _category = choice);
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
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final container = ProviderScope.containerOf(context);
      final modelTypeName = _category.name;

      var newStart = _start;
      var newEnd = _end;
      if (!newEnd.isAfter(newStart)) {
        newEnd = newEnd.add(const Duration(days: 1));
      }

      final notes = _notesController.text.trim();
      final request = SetModelRequest(
        id: widget.model.id,
        modelType:
            modelTypeName != widget.model.modelType?.name ? modelTypeName : null,
        name: name,
        description: notes.isEmpty ? null : notes,
        attributes: [
          req.ModelAttribute(
            key: 'start_time',
            value: newStart.toIso8601String(),
          ),
          req.ModelAttribute(
            key: 'end_time',
            value: newEnd.toIso8601String(),
          ),
        ],
      );

      await createModel(container, request);
      ref.invalidate(todaySnapshotProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('EditActionPage._save: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
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
      final container = ProviderScope.containerOf(context);
      await createModel(
        container,
        SetModelRequest(id: widget.model.id, delete: true),
      );
      ref.invalidate(todaySnapshotProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('EditActionPage._confirmDelete: $e\n$st');
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
                  const Expanded(
                    child: Text(
                      'Edit action',
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                  _borderBox(
                    child: TextField(
                      controller: _nameController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Action name',
                        hintStyle: TextStyle(color: AppColors.slate400),
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
                      child: _borderBox(
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _category.dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _category.label,
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
                                child: _borderBox(
                                  child: Center(
                                    child: Text(
                                      formatActionDateTime(_start),
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
                                child: _borderBox(
                                  child: Center(
                                    child: Text(
                                      formatActionDateTime(_end),
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
                            : () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => const TaskPickerPage(),
                                  ),
                                );
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
                  _borderBox(
                    minHeight: 64,
                    alignment: Alignment.topLeft,
                    child: TextField(
                      controller: _notesController,
                      enabled: !_saving,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Optional notes…',
                        hintStyle: TextStyle(color: AppColors.slate400),
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.slate700,
                        height: 1.5,
                      ),
                    ),
                  ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _borderBox({
    required Widget child,
    double minHeight = 0,
    AlignmentGeometry alignment = Alignment.centerLeft,
  }) {
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
