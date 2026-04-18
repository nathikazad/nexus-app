import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import '../../theme/app_colors.dart';
import '../../widgets/nx_tab_header.dart';
import '../../widgets/task_row_tile.dart';
import 'task_detail_page.dart';
import 'task_picker_page.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  static const _clock = '9:41 AM';

  void _openPicker(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const TaskPickerPage()),
    );
  }

  void _openTaskDetail(BuildContext context, TaskDetailArgs args) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => TaskDetailPage(args: args)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NxTabHeader(
          clockLabel: _clock,
          title: 'Tasks — Thu, Oct 26',
          bottomBorder: true,
          borderColor: AppColors.slate50,
          trailing: IconButton(
            onPressed: () => _openPicker(context),
            tooltip: 'Pick tasks',
            style: IconButton.styleFrom(
              foregroundColor: AppColors.accent,
              hoverColor: AppColors.accentLight,
            ),
            icon: const Icon(SolarLinearIcons.addCircle, size: 26),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.slate100)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip(label: '4 Total', bg: AppColors.slate100, border: AppColors.slate200, fg: AppColors.slate600),
                const SizedBox(width: 8),
                _Chip(
                  label: '2 Done',
                  bg: const Color(0xFFF0FDF4),
                  border: const Color(0xFFDCFCE7),
                  fg: const Color(0xFF15803D),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: '2 Todo',
                  bg: AppColors.slate50,
                  border: AppColors.slate100,
                  fg: AppColors.slate500,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              Text(
                'SWIPE RIGHT = DONE • LONG PRESS TO REORDER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate400,
                ),
              ),
              const SizedBox(height: 16),
              TaskRowTile(
                title: 'Review Q3 Analytics',
                subtitle: 'Growth › Reports',
                durationLabel: '45m',
                done: true,
                onTap: () => _openTaskDetail(
                  context,
                  const TaskDetailArgs(
                    title: 'Review Q3 Analytics',
                    subtitle: 'Growth › Reports',
                    durationLabel: '45m',
                  ),
                ),
              ),
              TaskRowTile(
                title: 'Reply to investors',
                subtitle: 'Admin',
                durationLabel: '15m',
                done: true,
                onTap: () => _openTaskDetail(
                  context,
                  const TaskDetailArgs(
                    title: 'Reply to investors',
                    subtitle: 'Admin',
                    durationLabel: '15m',
                  ),
                ),
              ),
              TaskRowTile(
                title: 'Draft weekly newsletter',
                subtitle: 'Content › Newsletter',
                durationLabel: '1h',
                done: false,
                onTap: () => _openTaskDetail(
                  context,
                  const TaskDetailArgs(
                    title: 'Draft weekly newsletter',
                    subtitle: 'Content › Newsletter',
                    durationLabel: '1h',
                  ),
                ),
              ),
              TaskRowTile(
                title: 'Gym: Upper Body',
                subtitle: 'Personal › Health',
                durationLabel: '1h 15m',
                done: false,
                onTap: () => _openTaskDetail(
                  context,
                  const TaskDetailArgs(
                    title: 'Gym: Upper Body',
                    subtitle: 'Personal › Health',
                    durationLabel: '1h 15m',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.bg,
    required this.border,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color border;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}
