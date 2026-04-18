import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/app_theme.dart';
import 'package:nx_time/features/tasks/projects_browse_page.dart';

/// Edit task (`reference/partials/page-task-edit.html`).
class TaskEditPage extends StatelessWidget {
  const TaskEditPage({
    super.key,
    this.title = 'Refactor token validation',
    this.parentTitle = 'Auth',
    this.parentSubtitle = 'Nexus App › Time App › Auth',
  });

  final String title;
  final String parentTitle;
  final String parentSubtitle;

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
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate500,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Edit task',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.slate100),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _fieldLabel('TASK NAME'),
                  const SizedBox(height: 8),
                  _fakeField(title),
                  const SizedBox(height: 20),
                  _fieldLabel('PARENT'),
                  const SizedBox(height: 8),
                  Material(
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    parentTitle,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.slate900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    parentSubtitle,
                                    style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.accent,
                              ),
                            ),
                            Icon(SolarLinearIcons.altArrowRight, size: 18, color: AppColors.slate400),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.slate100),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _fieldLabel('DATE (OPTIONAL)'),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _fakeField('Fri, Apr 17', center: true),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _fieldLabel('TIME (OPTIONAL)'),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _fakeField('2:00 PM', center: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _fakeField('3:30 PM', center: true)),
                    ],
                  ),
                  const Text(
                    'Time requires a date to be set',
                    style: TextStyle(fontSize: 11, color: AppColors.slate400),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.slate100),
                  const SizedBox(height: 20),
                  _fieldLabel('TAGS'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _removableTag('work', const Color(0xFFE0F2FE), const Color(0xFF075985)),
                      _removableTag('urgent', AppColors.accentLight, AppColors.accent),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.slate400,
                          side: const BorderSide(color: AppColors.slate200, style: BorderStyle.solid),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('+ add tag', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.slate100),
                  const SizedBox(height: 20),
                  _fieldLabel('NOTES'),
                  const SizedBox(height: 8),
                  _fakeField(
                    'Need to handle the edge case where tokens were issued before the schema change. Sam suggested using a version column.',
                    minLines: 3,
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.slate100),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(SolarLinearIcons.trashBinMinimalistic, size: 18),
                        SizedBox(width: 8),
                        Text('Delete task', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
        color: AppColors.slate500,
      ),
    );
  }

  static Widget _fakeField(String text, {bool center = false, int minLines = 1}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: const TextStyle(fontSize: 14, color: AppColors.slate900, height: 1.45),
        maxLines: minLines > 1 ? null : 1,
      ),
    );
  }

  static Widget _removableTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
          const SizedBox(width: 4),
          Icon(Icons.close, size: 14, color: fg.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}
