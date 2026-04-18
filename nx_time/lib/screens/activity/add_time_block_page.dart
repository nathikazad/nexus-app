import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_db/src/models/requests/SetModelRequest.dart' as req;

import '../../app_theme.dart';
import '../../data/action_category_option.dart';
import '../../providers/action_category_providers.dart';
import '../../providers/time_providers.dart';
import '../tasks/task_picker_page.dart';
import 'activity_pickers.dart';

/// Creates an Action row via `set_kgql_models`. Reference: `partials/page-add-time-block.html`.
class AddTimeBlockPage extends ConsumerStatefulWidget {
  const AddTimeBlockPage({super.key});

  @override
  ConsumerState<AddTimeBlockPage> createState() => _AddTimeBlockPageState();
}

class _AddTimeBlockPageState extends ConsumerState<AddTimeBlockPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  ActionCategoryOption? _category;
  late DateTime _start;
  late DateTime _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _notesController = TextEditingController();
    final n = DateTime.now();
    final d = DateTime(n.year, n.month, n.day);
    _start = DateTime(d.year, d.month, d.day, 9, 0);
    _end = DateTime(d.year, d.month, d.day, 10, 0);
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
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a type, start, and end')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final container = ProviderScope.containerOf(context);

      var start = _start;
      var end = _end;
      if (!end.isAfter(start)) {
        end = end.add(const Duration(days: 1));
      }

      final notes = _notesController.text.trim();
      final request = SetModelRequest(
        modelType: _category!.name,
        name: name,
        description: notes.isEmpty ? null : notes,
        attributes: [
          req.ModelAttribute(key: 'start_time', value: start.toIso8601String()),
          req.ModelAttribute(key: 'end_time', value: end.toIso8601String()),
        ],
      );

      await createModel(container, request);
      ref.invalidate(todaySnapshotProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('AddTimeBlockPage._save: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
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
                      'Add time block',
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'e.g., Evening walk, Reading…',
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
                      child: _OutlineField(
                        child: _category == null
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
                                      color: _category!.dotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _category!.label,
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
                                child: _OutlineField(
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
