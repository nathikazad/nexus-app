import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/features/tasks/project_drill_down_page.dart';

/// Reference: `reference/partials/page-projects-browse.html`
class ProjectsBrowsePage extends StatelessWidget {
  const ProjectsBrowsePage({super.key});

  static const _rows = <_ProjectRow>[
    _ProjectRow(title: 'Nexus App', subtitle: '3 sub-projects · 12 tasks', opensDrillDown: true),
    _ProjectRow(title: 'Cannatrols Fridge', subtitle: '2 sub-projects · 7 tasks'),
    _ProjectRow(title: 'Bondu Toys', subtitle: '4 tasks'),
    _ProjectRow(title: 'Personal', subtitle: '8 tasks'),
    _ProjectRow(title: 'Content', subtitle: '4 tasks'),
    _ProjectRow(title: 'Home', subtitle: '5 tasks'),
  ];

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
                      'Projects',
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
                      'Search projects…',
                      style: TextStyle(fontSize: 14, color: AppColors.slate400),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.slate100),
                itemBuilder: (context, i) {
                  final r = _rows[i];
                  return Material(
                    color: Colors.white,
                    child: InkWell(
                      onTap: r.opensDrillDown
                          ? () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute(builder: (_) => const ProjectDrillDownPage()),
                              );
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.slate900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    r.subtitle,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.slate500,
                                    ),
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectRow {
  const _ProjectRow({
    required this.title,
    required this.subtitle,
    this.opensDrillDown = false,
  });

  final String title;
  final String subtitle;
  final bool opensDrillDown;
}
