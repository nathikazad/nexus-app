import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import '../../theme/app_colors.dart';
import '../../widgets/task_status_segmented.dart';
import 'task_edit_page.dart';
import 'task_status.dart';

class TaskDetailArgs {
  const TaskDetailArgs({
    required this.title,
    required this.subtitle,
    required this.durationLabel,
    this.initialStatus = TaskStatus.progress,
  });

  final String title;
  final String subtitle;
  final String durationLabel;
  final TaskStatus initialStatus;
}

/// Task drill-in (`reference/partials/view-task-detail.html`).
class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({super.key, required this.args});

  final TaskDetailArgs args;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late TaskStatus _status;

  @override
  void initState() {
    super.initState();
    _status = widget.args.initialStatus;
  }

  bool get _isNewsletter => widget.args.title == 'Draft weekly newsletter';
  bool get _isAuthRefactor => widget.args.title == 'Refactor token validation';

  void _openEdit() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TaskEditPage(
          title: widget.args.title,
          parentTitle: _isAuthRefactor ? 'Auth' : 'Content',
          parentSubtitle: widget.args.subtitle,
        ),
      ),
    );
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
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(SolarLinearIcons.arrowLeft, size: 22),
                    color: AppColors.slate600,
                  ),
                  const Expanded(
                    child: Text(
                      'TASK',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _openEdit,
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (_isAuthRefactor) ...[
                    _authTitleBlock(),
                    const SizedBox(height: 20),
                    _authTags(),
                    const SizedBox(height: 20),
                    _dateTimeCard(),
                    const SizedBox(height: 16),
                    TaskStatusSegmented(
                      value: _status,
                      onChanged: (s) => setState(() => _status = s),
                    ),
                    const SizedBox(height: 24),
                    _authSubtasks(),
                    const SizedBox(height: 24),
                    _authNotes(),
                    const SizedBox(height: 24),
                    _authTimeSpent(),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _PartialCheckbox(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.args.title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  height: 1.15,
                                  color: AppColors.slate900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.args.subtitle,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.slate500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_isNewsletter) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Tag(text: 'due Friday', fg: AppColors.accent, bg: AppColors.accentLight),
                          _Tag(text: 'content', fg: AppColors.slate600, bg: AppColors.slate100),
                          OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.slate400,
                              side: const BorderSide(color: AppColors.slate200, style: BorderStyle.solid),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('+ tag', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TaskStatusSegmented(
                        value: _status,
                        onChanged: (s) => setState(() => _status = s),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'SUBTASKS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1,
                              color: AppColors.slate500,
                            ),
                          ),
                          const Text(
                            '0 of 3',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: const LinearProgressIndicator(
                          value: 0,
                          minHeight: 6,
                          backgroundColor: AppColors.slate100,
                          valueColor: AlwaysStoppedAnimation(AppColors.accent),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SubtaskRow(active: true, label: 'Outline sections', bold: true),
                      const SizedBox(height: 12),
                      _SubtaskRow(active: false, label: 'Pull metrics & quotes', bold: false),
                      const SizedBox(height: 12),
                      _SubtaskRow(active: false, label: 'Proofread & schedule send', bold: false),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.slate400,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('+ add subtask', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          const Text(
                            'Actions',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1,
                              color: AppColors.slate500,
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      const _TimeBlockColumn(),
                    ] else ...[
                      TaskStatusSegmented(
                        value: _status,
                        onChanged: (s) => setState(() => _status = s),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Duration planned: ${widget.args.durationLabel}',
                        style: const TextStyle(fontSize: 14, color: AppColors.slate600),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.slate100),
                  _DetailAction(
                    icon: SolarLinearIcons.calendar,
                    title: 'Move to different day',
                    subtitle: 'Repin this task',
                  ),
                  if (_isAuthRefactor)
                    _DetailAction(
                      icon: SolarLinearIcons.trashBinMinimalistic,
                      title: 'Delete task',
                      subtitle: 'This cannot be undone',
                      destructive: true,
                    )
                  else ...[
                    _DetailAction(
                      icon: SolarLinearIcons.archive,
                      title: 'Unpin from today',
                      subtitle: 'Send back to backlog',
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

  Widget _authTitleBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.args.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.15,
            color: AppColors.slate900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.args.subtitle,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.slate500,
          ),
        ),
      ],
    );
  }

  Widget _authTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'work',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF075985)),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'urgent',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.accent),
          ),
        ),
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.slate400,
            side: const BorderSide(color: AppColors.slate200, style: BorderStyle.solid),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('+ tag', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _dateTimeCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Text(
                  'DATE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: AppColors.slate400,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Fri, Apr 17',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate900),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 28, color: AppColors.slate200),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '2:00',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate900),
                ),
                Text(
                  ' PM',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.slate500),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(width: 12, height: 1, color: AppColors.slate300),
                ),
                const Text(
                  '3:30',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate900),
                ),
                Text(
                  ' PM',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.slate500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _authSubtasks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'SUBTASKS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
                color: AppColors.slate500,
              ),
            ),
            const Text(
              '3 of 5',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.slate900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: const LinearProgressIndicator(
            value: 0.6,
            minHeight: 6,
            backgroundColor: AppColors.slate100,
            valueColor: AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
        const SizedBox(height: 12),
        _authSubtaskRow(done: true, label: 'Set up schema diff tool'),
        _authSubtaskRow(done: true, label: 'Write forward migration'),
        _authSubtaskRow(done: true, label: 'Write rollback migration'),
        _authSubtaskRow(done: false, label: 'Wire up revocation endpoint', bold: true),
        _authSubtaskRow(done: false, label: 'Add integration tests', bold: false, showBorder: false),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            foregroundColor: AppColors.slate400,
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          child: const Text('+ add subtask', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _authSubtaskRow({
    required bool done,
    required String label,
    bool bold = false,
    bool showBorder = true,
  }) {
    return Container(
      decoration: showBorder
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.slate100)),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Opacity(
        opacity: done ? 0.5 : 1,
        child: Row(
          children: [
            if (done)
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.dotOk,
                  shape: BoxShape.circle,
                ),
                child: const Icon(SolarLinearIcons.checkRead, size: 12, color: Colors.white),
              )
            else
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: bold ? AppColors.accent : AppColors.slate300,
                    width: bold ? 2 : 1.5,
                  ),
                  color: bold ? AppColors.accentLight : Colors.transparent,
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: AppColors.slate900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _authNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NOTES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
            color: AppColors.slate500,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Need to handle the edge case where tokens were issued before the schema change. Sam suggested using a version column.',
          style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.slate600),
        ),
      ],
    );
  }

  Widget _authTimeSpent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Actions',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
                color: AppColors.slate500,
              ),
            ),
            const Text(
              '2h 45m total',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.slate900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF185FA5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deep work — auth refactor',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate900),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Today, 8:30 – 11:15 AM',
                      style: TextStyle(fontSize: 11, color: AppColors.slate400),
                    ),
                  ],
                ),
              ),
              const Text(
                '2h 45m',
                style: TextStyle(fontSize: 12, color: AppColors.slate500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PartialCheckbox extends StatelessWidget {
  const _PartialCheckbox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFB923C).withValues(alpha: 0.5), width: 2),
      ),
      clipBehavior: Clip.hardEdge,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 24 * 0.4,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.fg, required this.bg});

  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }
}

class _SmallMeta extends StatelessWidget {
  const _SmallMeta({required this.label, required this.value, required this.accent});

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent ? AppColors.accentLight : AppColors.slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent ? const Color(0xFFFFEDD5) : AppColors.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
              color: accent ? AppColors.accentHover : AppColors.slate400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: accent ? const Color(0xFF9A3412) : AppColors.slate900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({
    required this.active,
    required this.label,
    required this.bold,
  });

  final bool active;
  final String label;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.accentLight : Colors.transparent,
            border: Border.all(
              color: active ? AppColors.accent : AppColors.slate300,
              width: active ? 2 : 1,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
              color: bold ? AppColors.slate900 : AppColors.slate600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeBlockColumn extends StatelessWidget {
  const _TimeBlockColumn();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.slate100, width: 2)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Newsletter outline block',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate900),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Yesterday, 2:00p – 2:40p',
                          style: TextStyle(fontSize: 10, color: AppColors.slate500),
                        ),
                        Text('40m', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.slate400)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Today, 9:45a – now',
                          style: TextStyle(fontSize: 10, color: AppColors.slate500),
                        ),
                        Text('32m', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.accent)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? const Color(0xFFEF4444) : AppColors.slate900;
    final iconBg = destructive ? const Color(0xFFFEF2F2) : AppColors.slate100;
    final iconFg = destructive ? const Color(0xFFEF4444) : AppColors.slate600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: iconFg),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: fg)),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
