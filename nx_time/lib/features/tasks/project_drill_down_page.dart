import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/app_theme.dart';
import 'package:nx_time/features/tasks/project_drill_deep_page.dart';
import 'package:nx_time/features/tasks/task_pick_widgets.dart';

/// Reference: `reference/partials/page-project-drill-down.html`
class ProjectDrillDownPage extends StatelessWidget {
  const ProjectDrillDownPage({super.key});

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
                      'Nexus App',
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
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'All',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  _sectionLabel('Sub-projects'),
                  _navRow(
                    context,
                    title: 'Time App',
                    subtitle: '5 tasks',
                    onTap: () {},
                  ),
                  _navRow(
                    context,
                    title: 'Expense App',
                    subtitle: '4 tasks',
                    onTap: () {},
                  ),
                  _navRow(
                    context,
                    title: 'Server',
                    subtitle: '3 tasks',
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(builder: (_) => const ProjectDrillDeepPage()),
                      );
                    },
                  ),
                  _sectionLabel('Direct tasks'),
                  _taskRow(title: 'Update README', selected: false),
                  _taskRow(title: 'Set up CI/CD pipeline', selected: false),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: TaskPickFooter(
        selectedLabel: '2 selected',
        onDone: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  static Widget _sectionLabel(String text) {
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
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.slate500,
        ),
      ),
    );
  }

  static Widget _navRow(
    BuildContext context, {
    required String title,
    required String subtitle,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
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
              Icon(SolarLinearIcons.altArrowRight, size: 18, color: AppColors.slate400),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _taskRow({required String title, required bool selected}) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {},
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
