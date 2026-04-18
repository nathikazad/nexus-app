import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import '../../theme/app_colors.dart';
import 'projects_browse_page.dart';
import 'task_create_page.dart';
import 'task_pick_widgets.dart';

/// Pick backlog tasks to pin to today (`reference/partials/view-task-picker.html`).
class TaskPickerPage extends StatefulWidget {
  const TaskPickerPage({super.key});

  @override
  State<TaskPickerPage> createState() => _TaskPickerPageState();
}

class _PickerTask {
  const _PickerTask({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;
}

class _TaskPickerPageState extends State<TaskPickerPage> {
  /// Indices into [_lines] combined list.
  final Set<int> _selected = {0, 3};

  static const _yesterday = [
    _PickerTask(title: 'Fix Sorting', subtitle: 'Nexus App › Expense App'),
    _PickerTask(title: 'Draft blog post outline', subtitle: 'Content'),
    _PickerTask(title: 'Study high speed PCB design', subtitle: 'Nexus App › Server › PCB v3'),
  ];

  static const _recent = [
    _PickerTask(title: 'Refactor token validation', subtitle: 'Nexus App › Time App › Auth'),
    _PickerTask(title: 'Design the PCB', subtitle: 'Nexus App › Server › PCB v3'),
  ];

  void _toggle(int i) {
    setState(() {
      if (_selected.contains(i)) {
        _selected.remove(i);
      } else {
        _selected.add(i);
      }
    });
  }

  int get _count => _selected.length;

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
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(SolarLinearIcons.arrowLeft, size: 22),
                    color: AppColors.slate600,
                  ),
                  const Expanded(
                    child: Text(
                      'Pick tasks for today',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.slate200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(SolarLinearIcons.magnifer, size: 18, color: AppColors.slate400),
                    const SizedBox(width: 8),
                    Text(
                      'Search all tasks…',
                      style: TextStyle(fontSize: 14, color: AppColors.slate400),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  _sectionStrip(
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Unfinished from yesterday',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(_yesterday.length, (j) {
                    final i = j;
                    return _taskRow(
                      task: _yesterday[j],
                      selected: _selected.contains(i),
                      onTap: () => _toggle(i),
                    );
                  }),
                  _sectionStrip(
                    child: const Text(
                      'Recently worked on',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate500,
                      ),
                    ),
                  ),
                  ...List.generate(_recent.length, (j) {
                    final i = j + _yesterday.length;
                    return _taskRow(
                      task: _recent[j],
                      selected: _selected.contains(i),
                      onTap: () => _toggle(i),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(builder: (_) => const ProjectsBrowsePage()),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.slate200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(SolarLinearIcons.folder, size: 20, color: AppColors.slate600),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Choose from projects',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.slate900,
                                  ),
                                ),
                              ),
                              Icon(SolarLinearIcons.altArrowRight, size: 18, color: AppColors.slate400),
                            ],
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
      bottomNavigationBar: TaskPickFooter(
        selectedLabel: '$_count selected',
        onDone: () => Navigator.of(context).maybePop(),
        onNewTask: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const TaskCreatePage()),
          );
        },
      ),
    );
  }

  static Widget _sectionStrip({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      decoration: const BoxDecoration(
        color: AppColors.slate50,
        border: Border(
          top: BorderSide(color: AppColors.slate100),
          bottom: BorderSide(color: AppColors.slate100),
        ),
      ),
      child: child,
    );
  }

  Widget _taskRow({
    required _PickerTask task,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.slate100)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: TaskSquareCheck(selected: selected),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.subtitle,
                      style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                    ),
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
