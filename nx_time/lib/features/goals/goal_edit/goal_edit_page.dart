import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/goals/goal.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_selected_attribute.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';
import 'package:nx_time/features/calendar/calendar_providers.dart';
import 'package:nx_time/features/goals/goal_edit/goal_edit_providers.dart';
import 'package:nx_time/features/goals/goal_edit/goal_edit_view_model.dart';

class GoalEditPage extends ConsumerStatefulWidget {
  const GoalEditPage({super.key, this.mode = GoalEditMode.create, this.initial})
      : assert(
          mode == GoalEditMode.create || initial != null,
          'edit requires initial goal',
        );

  final GoalEditMode mode;
  final Goal? initial;

  @override
  ConsumerState<GoalEditPage> createState() => _GoalEditPageState();
}

class _GoalEditPageState extends ConsumerState<GoalEditPage> {
  late final TextEditingController _name;
  bool _saving = false;
  bool _active = true;
  GoalCadence _cadence = GoalCadence.daily;
  String _actionName = 'Sleep';
  GoalSelectedAttribute _attr = GoalSelectedAttribute.duration;
  GoalThresholdOp _op = GoalThresholdOp.gte;

  final TextEditingController _durationCtl = TextEditingController(text: '8');
  final TextEditingController _countCtl = TextEditingController(text: '3');
  TimeOfDay _timeOfDay = const TimeOfDay(hour: 7, minute: 0);

  final Set<int> _preferredDays = <int>{};
  TimeOfDay? _slotTime;
  bool _auto = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    if (widget.mode == GoalEditMode.edit && widget.initial != null) {
      _applyGoal(widget.initial!);
    } else {
      final d = Goal.draft();
      _name.text = d.label;
      _actionName = d.actionModelTypeName;
      _cadence = d.cadence;
      _attr = d.selectedAttribute;
      _op = d.op;
      _durationCtl.text = d.thresholdValue.toString();
    }
  }

  void _applyGoal(Goal g) {
    _name.text = g.label;
    _active = g.active;
    _actionName = g.actionModelTypeName;
    _cadence = g.cadence;
    _attr = g.selectedAttribute;
    _op = g.op;
    if (g.selectedAttribute == GoalSelectedAttribute.duration) {
      _durationCtl.text = g.thresholdValue.toString();
    }
    if (g.selectedAttribute == GoalSelectedAttribute.count) {
      _countCtl.text = g.thresholdValue.round().toString();
    }
    final m = g.thresholdValue.round();
    if (g.selectedAttribute == GoalSelectedAttribute.startTime ||
        g.selectedAttribute == GoalSelectedAttribute.endTime) {
      _timeOfDay = TimeOfDay(hour: m ~/ 60, minute: m % 60);
    }
    _preferredDays
      ..clear()
      ..addAll(g.preferredDays);
    _slotTime = (g.preferredTime != null && g.preferredTime!.isNotEmpty)
        ? _parseSlot(g.preferredTime!)
        : null;
    _auto = g.autoGenerateTasks;
  }

  TimeOfDay? _parseSlot(String s) {
    final p = s.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0].trim());
    final m = int.tryParse(p[1].trim());
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String? _formatSlot(TimeOfDay? t) {
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _name.dispose();
    _durationCtl.dispose();
    _countCtl.dispose();
    super.dispose();
  }

  bool get _showPreferred =>
      GoalEditViewModel.showPreferredSlots(cadence: _cadence, attr: _attr);

  bool get _isEdit => widget.mode == GoalEditMode.edit;

  static const _dowL = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  Goal _buildGoal({required bool active}) {
    final durationH = double.tryParse(_durationCtl.text) ?? 0;
    final countI = int.tryParse(_countCtl.text) ?? 0;
    return GoalEditViewModel.buildGoal(
      id: widget.initial?.id,
      label: _name.text,
      active: active,
      cadence: _cadence,
      actionModelTypeName: _actionName,
      selectedAttribute: _attr,
      op: _op,
      durationHours: durationH,
      count: countI,
      timeOfDay: _timeOfDay,
      preferredDays: _preferredDays,
      preferredTimeHHmm: _formatSlot(_slotTime),
      autoGenerate: _auto,
    );
  }

  Future<void> _save() async {
    final durationH = double.tryParse(_durationCtl.text) ?? 0;
    final countI = int.tryParse(_countCtl.text) ?? 0;
    final err = GoalEditViewModel.snackbarErrorForSave(
      label: _name.text,
      attr: _attr,
      durationHours: durationH,
      count: countI,
      timeOfDay: _timeOfDay,
      cadence: _cadence,
      autoCreate: _auto,
      preferredDays: _preferredDays,
    );
    if (err != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final built = _buildGoal(active: _active);
    setState(() => _saving = true);
    try {
      final repo = ref.read(goalRepositoryProvider);
      if (widget.mode == GoalEditMode.create) {
        await repo.create(built);
      } else {
        await repo.update(built);
      }
      if (!mounted) return;
      invalidateActionsAfterMutation(ref);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _togglePause() async {
    if (widget.initial?.id == null) return;
    setState(() {
      _active = !_active;
    });
    final built = _buildGoal(active: _active);
    setState(() => _saving = true);
    try {
      await ref.read(goalRepositoryProvider).update(built);
      if (!mounted) return;
      invalidateActionsAfterMutation(ref);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not pause: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final id = widget.initial?.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete goal'),
        content: const Text(
          'This stops tracking. Sessions stay in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.dotMiss),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(goalRepositoryProvider).delete(id);
      if (!mounted) return;
      invalidateActionsAfterMutation(ref);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _conditionHelper() {
    switch (_attr) {
      case GoalSelectedAttribute.duration:
        final hrs = double.tryParse(_durationCtl.text) ?? 0;
        final at = _op == GoalThresholdOp.lt ? 'less than' : 'at least';
        final period = _cadence == GoalCadence.weekly ? 'This week' : 'Each day';
        return '$period, hits when total ${_actionName.toLowerCase()} '
            'duration is $at ${_trim(hrs)} hours.';
      case GoalSelectedAttribute.count:
        final n = int.tryParse(_countCtl.text) ?? 0;
        final at = _op == GoalThresholdOp.lt ? 'less than' : 'at least';
        final period = _cadence == GoalCadence.weekly ? 'This week' : 'Each day';
        return '$period, hits when count of '
            '${_actionName.toLowerCase()}s is $at $n.';
      case GoalSelectedAttribute.startTime:
        final v = _formatSlot(_timeOfDay) ?? '';
        final at = _op == GoalThresholdOp.lt ? 'before' : 'at or after';
        return 'Each day, hits when ${_actionName.toLowerCase()} '
            'start time is $at $v.';
      case GoalSelectedAttribute.endTime:
        final v = _formatSlot(_timeOfDay) ?? '';
        final at = _op == GoalThresholdOp.lt ? 'before' : 'at or after';
        return 'Each day, hits when ${_actionName.toLowerCase()} '
            'end time is $at $v.';
    }
  }

  String _trim(num n) {
    if (n == n.toInt()) return n.toInt().toString();
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final optionsAsync = ref.watch(goalActionTypeOptionsProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  const SizedBox(height: 20),
                  _section('Name'),
                  const SizedBox(height: 8),
                  _nameField(),
                  const SizedBox(height: 16),
                  _section('Action type'),
                  const SizedBox(height: 8),
                  _actionTypeField(optionsAsync),
                  const SizedBox(height: 16),
                  _section('Cadence'),
                  const SizedBox(height: 8),
                  _cadencePill(),
                  const SizedBox(height: 16),
                  _section('Goal condition'),
                  const SizedBox(height: 8),
                  _conditionRow(),
                  const SizedBox(height: 8),
                  Text(
                    _conditionHelper(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.slate400,
                    ),
                  ),
                  if (_showPreferred) ...[
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.slate100, height: 1),
                    const SizedBox(height: 16),
                    _preferredSection(),
                  ],
                  if (_isEdit) ...[
                    const SizedBox(height: 24),
                    const Divider(color: AppColors.slate100, height: 1),
                    const SizedBox(height: 16),
                    _bottomEditActions(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final saveLabel =
        widget.mode == GoalEditMode.create ? 'Create' : 'Save';
    final title =
        widget.mode == GoalEditMode.create ? 'New goal' : 'Edit goal';
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.slate100, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _saving ? null : () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate500,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate900,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _saving ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Text(
                saveLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _saving
                      ? AppColors.slate300
                      : AppColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label, {bool optional = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.slate500,
            letterSpacing: 1.4,
          ),
        ),
        if (optional)
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Text(
              '(optional)',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.slate400,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }

  BoxDecoration get _fieldDecoration => BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(12),
      );

  Widget _nameField() {
    return Container(
      decoration: _fieldDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: _name,
        textCapitalization: TextCapitalization.sentences,
        enabled: !_saving,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.slate900,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
          hintText: 'e.g. Read 1 hour every day',
          hintStyle: TextStyle(
            fontSize: 14,
            color: AppColors.slate400,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _actionTypeField(AsyncValue<List<GoalActionTypeOption>> async) {
    return async.when(
      data: (opts) {
        if (opts.isEmpty) {
          return Container(
            decoration: _fieldDecoration,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: const Text(
              'No action types',
              style: TextStyle(color: AppColors.slate500),
            ),
          );
        }
        if (!opts.any((e) => e.name == _actionName)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _actionName = opts.first.name);
          });
        }
        final val = opts.any((e) => e.name == _actionName)
            ? _actionName
            : opts.first.name;
        return _customDropdown<String>(
          value: val,
          items: [
            for (final o in opts)
              DropdownMenuItem<String>(value: o.name, child: Text(o.name)),
          ],
          onChanged: _saving
              ? null
              : (v) {
                  if (v != null) setState(() => _actionName = v);
                },
        );
      },
      loading: () => Container(
        decoration: _fieldDecoration,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: const LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, _) => Container(
        decoration: _fieldDecoration,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _customDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Container(
      decoration: _fieldDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                isDense: true,
                icon: const SizedBox.shrink(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate900,
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
          const Icon(
            SolarLinearIcons.altArrowDown,
            size: 16,
            color: AppColors.slate400,
          ),
        ],
      ),
    );
  }

  Widget _cadencePill() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.slate100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pillButton(
              label: 'Daily',
              on: _cadence == GoalCadence.daily,
              onTap: _saving
                  ? null
                  : () => setState(() {
                        _cadence = GoalCadence.daily;
                      }),
            ),
            _pillButton(
              label: 'Weekly',
              on: _cadence == GoalCadence.weekly,
              onTap: _saving
                  ? null
                  : () => setState(() {
                        _cadence = GoalCadence.weekly;
                        _attr = GoalEditViewModel.clampAttributeForCadence(
                          _cadence,
                          _attr,
                        );
                      }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required bool on,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: on
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: on ? FontWeight.w600 : FontWeight.w500,
            color: on ? AppColors.accent : AppColors.slate500,
          ),
        ),
      ),
    );
  }

  Widget _conditionRow() {
    final canTime = _cadence == GoalCadence.daily;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: _customDropdown<GoalSelectedAttribute>(
            value: _attr,
            items: [
              const DropdownMenuItem(
                value: GoalSelectedAttribute.count,
                child: Text('Count'),
              ),
              const DropdownMenuItem(
                value: GoalSelectedAttribute.duration,
                child: Text('Duration'),
              ),
              if (canTime) ...const [
                DropdownMenuItem(
                  value: GoalSelectedAttribute.startTime,
                  child: Text('Start time'),
                ),
                DropdownMenuItem(
                  value: GoalSelectedAttribute.endTime,
                  child: Text('End time'),
                ),
              ],
            ],
            onChanged: _saving
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() => _attr = v);
                  },
          ),
        ),
        const SizedBox(width: 8),
        _opSegmented(),
        const SizedBox(width: 8),
        Expanded(flex: 5, child: _valueField()),
      ],
    );
  }

  Widget _opSegmented() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _opBtn('lt', '<', _op == GoalThresholdOp.lt),
          _opBtn('gte', '>', _op == GoalThresholdOp.gte),
        ],
      ),
    );
  }

  Widget _opBtn(String key, String label, bool on) {
    return GestureDetector(
      onTap: _saving
          ? null
          : () {
              setState(() {
                _op = key == 'lt'
                    ? GoalThresholdOp.lt
                    : GoalThresholdOp.gte;
              });
            },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: on
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: on ? AppColors.accent : AppColors.slate400,
          ),
        ),
      ),
    );
  }

  Widget _valueField() {
    if (_attr == GoalSelectedAttribute.duration) {
      return _numberWithUnit(
        controller: _durationCtl,
        unit: 'hrs',
        decimal: true,
        hint: '0',
      );
    }
    if (_attr == GoalSelectedAttribute.count) {
      return _numberWithUnit(
        controller: _countCtl,
        unit: _cadence == GoalCadence.weekly ? '/ wk' : '/ day',
        decimal: false,
        hint: '1',
      );
    }
    return _timeValueField();
  }

  Widget _numberWithUnit({
    required TextEditingController controller,
    required String unit,
    required bool decimal,
    required String hint,
  }) {
    return Container(
      height: 44,
      decoration: _fieldDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !_saving,
              keyboardType: TextInputType.numberWithOptions(decimal: decimal),
              inputFormatters: decimal
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                  : [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.slate900,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: const TextStyle(
                  color: AppColors.slate400,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.slate400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeValueField() {
    return GestureDetector(
      onTap: _saving
          ? null
          : () async {
              final t = await showTimePicker(
                context: context,
                initialTime: _timeOfDay,
              );
              if (t != null) setState(() => _timeOfDay = t);
            },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        decoration: _fieldDecoration,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Text(
          _timeOfDay.format(context),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.slate900,
          ),
        ),
      ),
    );
  }

  Widget _preferredSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Preferred days', optional: true),
        const SizedBox(height: 6),
        const Text(
          'Days you plan to do this. We won\u2019t require sessions only on these days.',
          style: TextStyle(fontSize: 11, color: AppColors.slate500),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(7, (i) {
            final on = _preferredDays.contains(i);
            return Padding(
              padding: EdgeInsets.only(right: i == 6 ? 0 : 6),
              child: GestureDetector(
                onTap: _saving
                    ? null
                    : () {
                        setState(() {
                          if (on) {
                            _preferredDays.remove(i);
                          } else {
                            _preferredDays.add(i);
                          }
                        });
                      },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? AppColors.accent : Colors.white,
                    border: Border.all(
                      color: on ? AppColors.accent : AppColors.slate200,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _dowL[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: on ? Colors.white : AppColors.slate400,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        _slotTimeTile(),
        const SizedBox(height: 6),
        const Text(
          'Optional \u2014 applies to every preferred day. Leave empty for no specific time.',
          style: TextStyle(fontSize: 11, color: AppColors.slate400),
        ),
        const SizedBox(height: 8),
        _autoToggleRow(),
      ],
    );
  }

  Widget _slotTimeTile() {
    return GestureDetector(
      onTap: _saving
          ? null
          : () async {
              final t = await showTimePicker(
                context: context,
                initialTime:
                    _slotTime ?? const TimeOfDay(hour: 12, minute: 30),
              );
              if (t != null) setState(() => _slotTime = t);
            },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        decoration: _fieldDecoration,
        padding: const EdgeInsets.only(left: 14, right: 6),
        child: Row(
          children: [
            const Icon(
              SolarLinearIcons.clockCircle,
              size: 16,
              color: AppColors.slate400,
            ),
            const SizedBox(width: 8),
            const Text(
              'Time',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.slate500,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  _slotTime == null ? '' : _formatSlot(_slotTime) ?? '',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate900,
                  ),
                ),
              ),
            ),
            if (_slotTime != null)
              GestureDetector(
                onTap: _saving
                    ? null
                    : () => setState(() => _slotTime = null),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  child: const Icon(
                    SolarLinearIcons.closeCircle,
                    size: 16,
                    color: AppColors.slate300,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _autoToggleRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-create slot tasks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Drop a task on each day so it shows in Tasks',
                  style: TextStyle(fontSize: 11, color: AppColors.slate500),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _saving ? null : () => setState(() => _auto = !_auto),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 24,
              decoration: BoxDecoration(
                color: _auto ? AppColors.accent : AppColors.slate200,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 150),
                    alignment:
                        _auto ? Alignment.centerRight : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomEditActions() {
    return Column(
      children: [
        _outlinedActionButton(
          icon: SolarLinearIcons.pause,
          label: _active ? 'Pause goal' : 'Resume goal',
          onTap: _saving ? null : _togglePause,
        ),
        const SizedBox(height: 10),
        _outlinedActionButton(
          icon: SolarLinearIcons.trashBinMinimalistic,
          label: 'Delete goal',
          onTap: _saving ? null : _delete,
          danger: true,
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Sessions stay in your history; only the goal stops tracking.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.slate400),
          ),
        ),
      ],
    );
  }

  Widget _outlinedActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool danger = false,
  }) {
    final color = danger ? AppColors.dotMiss : AppColors.slate700;
    final border = danger
        ? const Color(0xFFFECDD3)
        : AppColors.slate200;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
