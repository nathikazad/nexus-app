import 'package:flutter/material.dart';

import '../../data/models/today_snapshot.dart';
import '../../theme/app_colors.dart';
import 'widgets/activity_row.dart';
import 'widgets/category_legend.dart';
import 'widgets/time_map_bar.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.snapshot,
    this.onWeekViewTap,
    this.onActivityTap,
    this.onAddManualTap,
  });

  final TodaySnapshot snapshot;
  final VoidCallback? onWeekViewTap;
  final void Function(int index)? onActivityTap;
  final VoidCallback? onAddManualTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TodayHeader(
          clockLabel: snapshot.clockLabel,
          titleLine: snapshot.titleLine,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            children: [
              TimeMapBar(
                segments: snapshot.timeMapSegments,
                currentMarkerFraction: snapshot.currentMarkerFraction,
                onWeekViewTap: onWeekViewTap,
              ),
              const SizedBox(height: 12),
              CategoryLegend(items: snapshot.legend),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Activities',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    '${snapshot.activityBlockCount} blocks',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < snapshot.activities.length; i++) ...[
                ActivityRow(
                  activity: snapshot.activities[i],
                  onTap: onActivityTap != null ? () => onActivityTap!(i) : null,
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onAddManualTap,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.slate200, style: BorderStyle.solid),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  foregroundColor: AppColors.slate500,
                ),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text(
                  'Add time block manually',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.clockLabel,
    required this.titleLine,
  });

  final String clockLabel;
  final String titleLine;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              clockLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.slate500,
              ),
            ),
            Expanded(
              child: Text(
                titleLine,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.settings_outlined),
              color: AppColors.slate500,
              iconSize: 24,
            ),
          ],
        ),
      ),
    );
  }
}
