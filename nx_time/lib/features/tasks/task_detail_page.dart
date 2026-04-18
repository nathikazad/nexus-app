import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import '../../theme/app_colors.dart';

class TaskDetailArgs {
  const TaskDetailArgs({
    required this.title,
    required this.subtitle,
    required this.durationLabel,
  });

  final String title;
  final String subtitle;
  final String durationLabel;
}

/// Task drill-in (`view-task-detail.html`); defaults match newsletter row.
class TaskDetailPage extends StatelessWidget {
  const TaskDetailPage({super.key, required this.args});

  final TaskDetailArgs args;

  @override
  Widget build(BuildContext context) {
    final showNewsletterDemo = args.title == 'Draft weekly newsletter';

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
                    onPressed: () {},
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFEF4444),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PartialCheckbox(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              args.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                                color: AppColors.slate900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              args.subtitle,
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
                  if (showNewsletterDemo) ...[
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
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: _SmallMeta(label: 'Created', value: 'Oct 20', accent: false),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SmallMeta(label: 'Pinned to', value: 'Today', accent: true),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SmallMeta(label: 'Time spent', value: '1h 12m', accent: false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
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
                          'TIME BLOCKS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1,
                            color: AppColors.slate500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.slate100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Auto-linked',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.slate500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _TimeBlockColumn(),
                  ] else ...[
                    Text(
                      'Duration planned: ${args.durationLabel}',
                      style: const TextStyle(fontSize: 14, color: AppColors.slate600),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.slate100),
                  _DetailAction(
                    icon: SolarLinearIcons.calendar,
                    title: 'Move to different day',
                    subtitle: 'Repin this task',
                  ),
                  _DetailAction(
                    icon: SolarLinearIcons.archive,
                    title: 'Unpin from today',
                    subtitle: 'Send back to backlog',
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

class _PartialCheckbox extends StatelessWidget {
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
                        const SizedBox(width: 8),
                        const Text(
                          'Current session',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
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
                decoration: const BoxDecoration(
                  color: AppColors.slate100,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: AppColors.slate600),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.slate900)),
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
