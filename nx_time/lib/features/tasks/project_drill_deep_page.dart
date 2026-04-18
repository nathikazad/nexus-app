import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/app_theme.dart';
import 'package:nx_time/features/tasks/task_pick_widgets.dart';

/// Reference: `reference/partials/page-project-drill-deep.html`
class ProjectDrillDeepPage extends StatefulWidget {
  const ProjectDrillDeepPage({super.key});

  @override
  State<ProjectDrillDeepPage> createState() => _ProjectDrillDeepPageState();
}

class _ProjectDrillDeepPageState extends State<ProjectDrillDeepPage> {
  /// Row indices for toggleable lines (0–4 map to main rows; sub-rows use separate keys).
  final Set<int> _selected = {0, 1, 3};

  void _toggle(int i) {
    setState(() {
      if (_selected.contains(i)) {
        _selected.remove(i);
      } else {
        _selected.add(i);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = _selected.length;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(SolarLinearIcons.arrowLeft, size: 22),
                    color: AppColors.slate600,
                  ),
                  const Expanded(
                    child: Text(
                      'Server',
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
              child: Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                  Text('›', style: TextStyle(fontSize: 12, color: AppColors.slate300)),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Nexus App', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                    decoration: const BoxDecoration(
                      color: AppColors.slate50,
                      border: Border(
                        top: BorderSide(color: AppColors.slate100),
                        bottom: BorderSide(color: AppColors.slate100),
                      ),
                    ),
                    child: const Text(
                      'Tasks',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate500,
                      ),
                    ),
                  ),
                  _expandRow(
                    title: 'PCB v3',
                    subtitle: '2 subtasks',
                    expandLabel: 'expand',
                    trailingIcon: SolarLinearIcons.altArrowDown,
                    selected: _selected.contains(0),
                    onToggle: () => _toggle(0),
                  ),
                  _indentedRow(
                    title: 'Study high speed PCB design',
                    selected: _selected.contains(1),
                    onToggle: () => _toggle(1),
                    dense: true,
                  ),
                  _indentedRow(
                    title: 'Design the PCB',
                    selected: _selected.contains(2),
                    onToggle: () => _toggle(2),
                    dense: true,
                  ),
                  _expandRow(
                    title: 'Set up monitoring',
                    subtitle: '3 subtasks',
                    expandLabel: 'expand',
                    trailingIcon: SolarLinearIcons.altArrowRight,
                    selected: _selected.contains(3),
                    onToggle: () => _toggle(3),
                  ),
                  _plainRow(
                    title: 'Order replacement capacitors',
                    selected: _selected.contains(4),
                    onToggle: () => _toggle(4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: TaskPickFooter(
        selectedLabel: '$count selected',
        onDone: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  Widget _expandRow({
    required String title,
    required String subtitle,
    required String expandLabel,
    required IconData trailingIcon,
    required bool selected,
    required VoidCallback onToggle,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.slate100)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              TaskSquareCheck(selected: selected),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
              Text(
                expandLabel,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.accent),
              ),
              const SizedBox(width: 4),
              Icon(trailingIcon, size: 16, color: AppColors.slate400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _indentedRow({
    required String title,
    required bool selected,
    required VoidCallback onToggle,
    bool dense = false,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.slate100)),
          ),
          padding: EdgeInsets.fromLTRB(48, dense ? 8 : 10, 20, dense ? 8 : 10),
          child: Row(
            children: [
              TaskSquareCheck(selected: selected),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: dense ? 13 : 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plainRow({
    required String title,
    required bool selected,
    required VoidCallback onToggle,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              TaskSquareCheck(selected: selected),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
