import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/features/shell/nx_app_menu_button.dart';
import 'package:nx_time/features/today/today_view_model.dart';
import 'package:nx_time/features/today/widgets/activity_row.dart';
import 'package:nx_time/features/today/widgets/time_map_bar.dart';

/// Header row + time bar height below the status bar (includes [TimeMapBar] + padding; tuned for device text scale).
const _kTodayPinnedBelowStatusBar = 138.0;

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.snapshot,
    this.onActivityTap,
    this.onChildTap,
    this.onAddManualTap,
  });

  final TodaySnapshot snapshot;
  final void Function(int index)? onActivityTap;
  final void Function(int rowIndex, int childIndex)? onChildTap;
  final VoidCallback? onAddManualTap;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return CustomScrollView(
      clipBehavior: Clip.hardEdge,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _TodayPinnedHeaderDelegate(
            topInset: topInset,
            snapshot: snapshot,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              for (var i = 0; i < snapshot.actions.length; i++) ...[
                ActivityRow(
                  activity: snapshot.actions[i],
                  onTap: onActivityTap != null ? () => onActivityTap!(i) : null,
                  onChildTap: onChildTap != null
                      ? (ci) => onChildTap!(i, ci)
                      : null,
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
            ]),
          ),
        ),
      ],
    );
  }
}

class _TodayPinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TodayPinnedHeaderDelegate({
    required this.topInset,
    required this.snapshot,
  });

  final double topInset;
  final TodaySnapshot snapshot;

  @override
  double get minExtent => topInset + _kTodayPinnedBelowStatusBar;

  @override
  double get maxExtent => topInset + _kTodayPinnedBelowStatusBar;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: maxExtent,
      child: Material(
        color: Colors.white,
        elevation: overlapsContent ? 0.5 : 0,
        shadowColor: AppColors.slate200.withValues(alpha: 0.9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: topInset),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: SizedBox(
                height: 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Text(
                        snapshot.titleLine,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: NxAppMenuButton(),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: TimeMapBar(
                segments: snapshot.timeMapSegments,
                currentMarkerFraction: snapshot.currentMarkerFraction,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TodayPinnedHeaderDelegate oldDelegate) {
    return oldDelegate.topInset != topInset ||
        oldDelegate.snapshot != snapshot;
  }
}
