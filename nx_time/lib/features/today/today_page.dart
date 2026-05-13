import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/domain/log/daily_log.dart';
import 'package:nx_time/features/shell/nx_app_menu_button.dart';
import 'package:nx_time/features/today/log_view_model.dart';
import 'package:nx_time/features/today/today_view_model.dart';
import 'package:nx_time/features/today/widgets/activity_row.dart';
import 'package:nx_time/features/today/widgets/log_row.dart';
import 'package:nx_time/features/today/widgets/time_map_bar.dart';
import 'package:nx_time/features/today/widgets/today_view_toggle.dart';

/// Header row + time bar + toggle row (tuned for device text scale).
const _kTodayPinnedBelowStatusBar = 184.0;

class TodayPage extends ConsumerWidget {
  const TodayPage({
    super.key,
    required this.snapshot,
    this.onActivityTap,
    this.onChildTap,
    this.onAddManualTap,
    this.onLogTap,
    this.onAddLogTap,
  });

  final TodaySnapshot snapshot;
  final void Function(int index)? onActivityTap;
  final void Function(int rowIndex, int childIndex)? onChildTap;
  final VoidCallback? onAddManualTap;
  final void Function(DailyLog log)? onLogTap;
  final VoidCallback? onAddLogTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = MediaQuery.paddingOf(context).top;
    final mode = ref.watch(todayViewModeProvider);

    return CustomScrollView(
      clipBehavior: Clip.hardEdge,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _TodayPinnedHeaderDelegate(
            topInset: topInset,
            snapshot: snapshot,
            mode: mode,
            onModeChanged: (m) =>
                ref.read(todayViewModeProvider.notifier).set(m),
          ),
        ),
        if (mode == TodayViewMode.actions)
          _buildActionsSliver(context)
        else
          _buildLogsSliver(context, ref),
      ],
    );
  }

  Widget _buildActionsSliver(BuildContext context) {
    return SliverPadding(
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
          _DashedAddButton(
            label: 'Add time block manually',
            onTap: onAddManualTap,
          ),
        ]),
      ),
    );
  }

  Widget _buildLogsSliver(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(todayLogsProvider);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      sliver: logsAsync.when(
        data: (logs) {
          return SliverList(
            delegate: SliverChildListDelegate([
              if (logs.isEmpty) ...[
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'No logs yet today',
                    style: TextStyle(fontSize: 13, color: AppColors.slate400),
                  ),
                ),
                const SizedBox(height: 16),
              ] else
                for (final log in logs) ...[
                  LogRow(
                    log: log,
                    onTap: onLogTap != null ? () => onLogTap!(log) : null,
                  ),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 12),
              _DashedAddButton(label: 'Add log', onTap: onAddLogTap),
            ]),
          );
        },
        loading: () => const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
        error: (e, _) => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Could not load logs: $e',
                style: const TextStyle(fontSize: 13, color: AppColors.slate500),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedAddButton extends StatelessWidget {
  const _DashedAddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DottedBorder(
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
          onTap: onTap,
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
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: AppColors.slate500,
                    fontFamily: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayPinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TodayPinnedHeaderDelegate({
    required this.topInset,
    required this.snapshot,
    required this.mode,
    required this.onModeChanged,
  });

  final double topInset;
  final TodaySnapshot snapshot;
  final TodayViewMode mode;
  final ValueChanged<TodayViewMode> onModeChanged;

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
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TodayViewToggle(mode: mode, onChanged: onModeChanged),
                ],
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
        oldDelegate.snapshot != snapshot ||
        oldDelegate.mode != mode;
  }
}
