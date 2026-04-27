import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/sprint/sprint_state.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';

class SprintCreatePanel extends ConsumerStatefulWidget {
  const SprintCreatePanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<SprintCreatePanel> createState() => _SprintCreatePanelState();
}

class _SprintCreatePanelState extends ConsumerState<SprintCreatePanel> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _start;
  late final TextEditingController _length;
  late final TextEditingController _goal;
  SprintState _state = SprintState.planned;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final sprints = ref.read(sprintsListProvider);
    final currentIdx = ref.read(sprintIndexProvider);
    final current = currentIdx >= 0 && currentIdx < sprints.length
        ? sprints[currentIdx]
        : (sprints.isNotEmpty ? sprints.last : null);
    final start = current == null
        ? DateTime.now()
        : parseLocalDate(current.start).add(Duration(days: current.length));
    _name = TextEditingController(text: _defaultName(start));
    _start = TextEditingController(text: formatYmd(start));
    _length = TextEditingController(text: (current?.length ?? 7).toString());
    _goal = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _start.dispose();
    _length.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final length = int.parse(_length.text.trim());
    setState(() => _saving = true);
    try {
      final created = await ref
          .read(sprintRepositoryProvider)
          .create(
            Sprint(
              id: 0,
              name: _name.text.trim(),
              dates: '',
              badge: _state.name,
              start: _start.text.trim(),
              length: length,
              capH: 0,
              state: _state,
              goal: _goal.text.trim(),
            ),
          );
      final refreshed = await ref.refresh(sprintsListAsyncProvider.future);
      final idx = refreshed.indexWhere((s) => s.id == created.id);
      if (idx >= 0) {
        ref.read(sprintIndexProvider.notifier).set(idx);
      }
      widget.onClose();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              children: [
                _field(
                  controller: _name,
                  label: 'Name',
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _start,
                  label: 'Start date',
                  hint: 'YYYY-MM-DD',
                  validator: _validateYmd,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _length,
                  label: 'Length',
                  hint: '7',
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n < 1) return 'Enter at least 1 day';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SprintState>(
                  initialValue: _state,
                  dropdownColor: AppColors.panel2,
                  decoration: _inputDecoration('Status'),
                  items: const [
                    DropdownMenuItem(
                      value: SprintState.planned,
                      child: Text('Planned'),
                    ),
                    DropdownMenuItem(
                      value: SprintState.active,
                      child: Text('Active'),
                    ),
                    DropdownMenuItem(
                      value: SprintState.done,
                      child: Text('Done'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _state = v);
                  },
                ),
                const SizedBox(height: 12),
                _field(controller: _goal, label: 'Goal', maxLines: 4),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : widget.onClose,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Create sprint'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _defaultName(DateTime start) {
    return 'Sprint ${formatYmd(start).substring(5)}';
  }

  String? _validateYmd(String? v) {
    final value = v?.trim() ?? '';
    final parsed = DateTime.tryParse('${value}T12:00:00');
    if (parsed == null || formatYmd(parsed) != value) {
      return 'Use YYYY-MM-DD';
    }
    return null;
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppColors.text, fontSize: 13),
      cursorColor: AppColors.accent,
      decoration: _inputDecoration(label, hint: hint),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.muted),
      hintStyle: const TextStyle(color: AppColors.dim),
      filled: true,
      fillColor: AppColors.panel2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    );
  }
}
