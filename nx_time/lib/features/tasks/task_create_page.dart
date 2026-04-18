import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/app_theme.dart';
import 'package:nx_time/features/tasks/projects_browse_page.dart';

/// New task (`reference/partials/page-task-create.html`).
class TaskCreatePage extends StatelessWidget {
  const TaskCreatePage({super.key});

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
                      'New task',
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
                    onPressed: null,
                    child: Text(
                      'Create',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate300,
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
                  _label('TASK NAME'),
                  const SizedBox(height: 8),
                  _placeholderField('What needs to be done?'),
                  const SizedBox(height: 20),
                  _label('PARENT'),
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
                            Icon(SolarLinearIcons.folder, size: 20, color: AppColors.slate400),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'None — standalone task',
                                style: TextStyle(fontSize: 14, color: AppColors.slate400),
                              ),
                            ),
                            const Text(
                              'Select',
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
                  _label('DATE (OPTIONAL)'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill('Today'),
                      _pill('Tomorrow'),
                      _pill('Pick date', icon: SolarLinearIcons.calendar),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _label('TIME (OPTIONAL)'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.slate50,
                            border: Border.all(color: AppColors.slate200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Start',
                            style: TextStyle(fontSize: 14, color: AppColors.slate400),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.slate50,
                            border: Border.all(color: AppColors.slate200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'End',
                            style: TextStyle(fontSize: 14, color: AppColors.slate400),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Set a date first to enable time',
                    style: TextStyle(fontSize: 11, color: AppColors.slate400),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.slate100),
                  const SizedBox(height: 20),
                  _label('TAGS (OPTIONAL)'),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.slate100),
                  const SizedBox(height: 20),
                  _label('NOTES (OPTIONAL)'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.slate200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Add any context...',
                      style: TextStyle(fontSize: 13, color: AppColors.slate400, height: 1.45),
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

  static Widget _label(String text) {
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

  static Widget _placeholderField(String hint) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        hint,
        style: const TextStyle(fontSize: 14, color: AppColors.slate400),
      ),
    );
  }

  static Widget _pill(String text, {IconData? icon}) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.slate600,
        side: const BorderSide(color: AppColors.slate200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.slate600),
            const SizedBox(width: 4),
          ],
          Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
