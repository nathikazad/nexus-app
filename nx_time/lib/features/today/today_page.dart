import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import '../../data/models/today_snapshot.dart';
import '../../theme/app_colors.dart';
import '../../widgets/nx_app_menu_button.dart';
import 'widgets/activity_row.dart';
import 'widgets/category_legend.dart';
import 'widgets/time_map_bar.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.snapshot,
    this.onActivityTap,
    this.onAddManualTap,
  });

  final TodaySnapshot snapshot;
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
            clipBehavior: Clip.none,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            children: [
              TimeMapBar(
                segments: snapshot.timeMapSegments,
                currentMarkerFraction: snapshot.currentMarkerFraction,
              ),
              const SizedBox(height: 12),
              CategoryLegend(items: snapshot.legend),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Actions',
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
              for (var i = 0; i < snapshot.actions.length; i++) ...[
                ActivityRow(
                  activity: snapshot.actions[i],
                  onTap: onActivityTap != null ? () => onActivityTap!(i) : null,
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 12),
              DottedBorder(
                options: const RoundedRectDottedBorderOptions(
                  radius: Radius.circular(12),
                  color: AppColors.slate200,
                  dashPattern: [4, 4],
                  strokeWidth: 1,
                  padding: EdgeInsets.zero,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onAddManualTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            SolarLinearIcons.addCircle,
                            size: 20,
                            color: AppColors.slate500,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Add time block manually',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: AppColors.slate500,
                              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                            ),
                          ),
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
            const NxAppMenuButton(),
          ],
        ),
      ),
    );
  }
}
