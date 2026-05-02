import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nx_time/core/layout/layout.dart';
import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/data/log/log_schema_view_provider.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/log/daily_log.dart';
import 'package:nx_time/domain/schema/model_type_view.dart';
import 'package:nx_time/features/action_edit/widgets/action_datetime_picker.dart';
import 'package:nx_time/features/log_edit/widgets/tag_picker.dart';
import 'package:nx_time/features/today/log_view_model.dart';

enum LogEditMode { create, edit }

/// Create or edit a Daily Log entry.
class LogEditPage extends ConsumerStatefulWidget {
  const LogEditPage({super.key, this.mode = LogEditMode.create, this.initial});

  final LogEditMode mode;
  final DailyLog? initial;

  @override
  ConsumerState<LogEditPage> createState() => _LogEditPageState();
}

class _LogEditPageState extends ConsumerState<LogEditPage> {
  late final TextEditingController _entryController;
  late DateTime _loggedAt;
  late Map<String, List<String>> _tags;
  bool _saving = false;

  bool get _isCreate => widget.mode == LogEditMode.create;

  @override
  void initState() {
    super.initState();
    if (_isCreate) {
      _entryController = TextEditingController();
      _loggedAt = DateTime.now();
      _tags = {};
    } else {
      final l = widget.initial!;
      _entryController = TextEditingController(text: l.entry ?? '');
      _loggedAt = l.loggedAt ?? DateTime.now();
      _tags = {
        for (final e in (l.tags ?? const <String, List<String>>{}).entries)
          e.key: List<String>.from(e.value),
      };
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _pickLoggedAt() async {
    final t = await showActionDateTimePicker(
      context,
      initialDateTime: _loggedAt,
      title: 'Logged at',
    );
    if (t != null && mounted) {
      setState(() => _loggedAt = t);
    }
  }

  Future<void> _save() async {
    final entry = _entryController.text.trim();
    setState(() => _saving = true);
    try {
      final repo = ref.read(logRepositoryProvider);
      if (_isCreate) {
        await repo.create(
          loggedAt: _loggedAt,
          entry: entry.isEmpty ? null : entry,
          tags: {
            for (final e in _tags.entries) e.key: List<String>.from(e.value),
          },
        );
      } else {
        await repo.update(
          id: widget.initial!.id,
          loggedAt: _loggedAt,
          entry: entry.isEmpty ? null : entry,
          tags: {
            for (final e in _tags.entries) e.key: List<String>.from(e.value),
          },
        );
      }
      invalidateLogsAfterMutation(ref);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, st) {
      debugPrint('LogEditPage._save: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (_isCreate) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this log?'),
        content: const Text('This removes the log entry.'),
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
      await ref.read(logRepositoryProvider).delete(widget.initial!.id);
      invalidateLogsAfterMutation(ref);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, st) {
      debugPrint('LogEditPage._confirmDelete: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isCreate ? 'Add log' : 'Edit log';
    final loggedFmt = DateFormat('EEE, MMM d · h:mm a');
    final schemaAsync = ref.watch(logSchemaViewProvider);
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
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).maybePop(),
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  const Text(
                    'Logged at',
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
                      onTap: _saving ? null : _pickLoggedAt,
                      borderRadius: BorderRadius.circular(10),
                      child: _OutlineField(
                        child: Text(
                          loggedFmt.format(_loggedAt),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.slate900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  schemaAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Could not load tags: $e',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.slate500,
                        ),
                      ),
                    ),
                    data: (schema) {
                      _ensureTagSystems(schema);
                      final systems = schema.tagSystems;
                      if (systems.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Tags', style: refSectionTitle(context)),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                RefLayout.rounded2xl,
                              ),
                              border: Border.all(color: AppColors.slate100),
                              boxShadow: refCardShadow,
                            ),
                            child: Column(
                              children: [
                                for (var i = 0; i < systems.length; i++) ...[
                                  TagPickerRow(
                                    system: systems[i],
                                    value: _tags[systems[i].name] ?? [],
                                    onChanged: (v) => setState(
                                      () => _tags[systems[i].name] = v,
                                    ),
                                  ),
                                  if (i < systems.length - 1)
                                    const Divider(
                                      height: 1,
                                      color: AppColors.slate50,
                                    ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),
                  const Text(
                    'Entry',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _OutlineField(
                    alignment: Alignment.topLeft,
                    minHeight: 160,
                    child: TextField(
                      controller: _entryController,
                      enabled: !_saving,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'What\'s on your mind?',
                        hintStyle: TextStyle(color: AppColors.slate400),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.slate900,
                        height: 1.5,
                      ),
                    ),
                  ),
                  if (!_isCreate) ...[
                    const SizedBox(height: 16),
                    Divider(
                      height: 1,
                      color: AppColors.slate100.withValues(alpha: 0.9),
                    ),
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
                            'Delete log',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.red600,
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

  void _ensureTagSystems(ModelTypeView schema) {
    for (final ts in schema.tagSystems) {
      _tags.putIfAbsent(ts.name, () => []);
    }
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
