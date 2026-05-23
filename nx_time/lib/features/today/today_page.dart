import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/data/providers.dart';
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
    final colors = modelTypeColorsOrFallback(
      ref.watch(modelTypeColorsProvider),
    );

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
          _buildTimelineSliver(context, ref)
        else
          _buildStatsSliver(colors),
      ],
    );
  }

  Widget _buildTimelineSliver(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(todayLogsProvider);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      sliver: logsAsync.when(
        data: (logs) {
          final entries = _buildTimelineEntries(snapshot, logs);
          return SliverList(
            delegate: SliverChildListDelegate([
              if (entries.isEmpty) ...[
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'No actions or logs yet today',
                    style: TextStyle(fontSize: 13, color: AppColors.slate400),
                  ),
                ),
                const SizedBox(height: 16),
              ] else
                for (final entry in entries) ..._widgetsForTimelineEntry(entry),
              const SizedBox(height: 12),
              _TimelineAddActions(
                onAddManualTap: onAddManualTap,
                onAddLogTap: onAddLogTap,
              ),
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

  List<Widget> _widgetsForTimelineEntry(_TodayTimelineEntry entry) {
    final log = entry.log;
    if (log != null) {
      return [
        LogRow(log: log, onTap: onLogTap != null ? () => onLogTap!(log) : null),
        const SizedBox(height: 8),
      ];
    }

    final actionIndex = entry.actionIndex!;
    return [
      ActivityRow(
        activity: snapshot.actions[actionIndex],
        onTap: onActivityTap != null ? () => onActivityTap!(actionIndex) : null,
        onChildTap: onChildTap != null
            ? (ci) => onChildTap!(actionIndex, ci)
            : null,
      ),
      const SizedBox(height: 4),
    ];
  }

  Widget _buildStatsSliver(ModelTypeColors colors) {
    final stats = _statsForToday(snapshot, colors);
    if (stats.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            'No actions',
            style: TextStyle(fontSize: 14, color: AppColors.slate500),
          ),
        ),
      );
    }
    final maxMinutes = stats.first.totalMinutes;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      sliver: SliverList.builder(
        itemCount: stats.length,
        itemBuilder: (context, i) {
          final stat = stats[i];
          final fraction = maxMinutes <= 0
              ? 0.0
              : stat.totalMinutes / maxMinutes;
          return _TodayStatRow(stat: stat, fraction: fraction);
        },
      ),
    );
  }
}

class _TodayActionStat {
  _TodayActionStat({required this.label, required this.color});

  final String label;
  final Color color;
  int totalMinutes = 0;
}

class _TodayTimelineEntry {
  const _TodayTimelineEntry.action({
    required this.sortTime,
    required this.actionIndex,
  }) : log = null;

  const _TodayTimelineEntry.log({required this.sortTime, required this.log})
    : actionIndex = null;

  final DateTime? sortTime;
  final int? actionIndex;
  final DailyLog? log;
}

List<_TodayTimelineEntry> _buildTimelineEntries(
  TodaySnapshot snapshot,
  List<DailyLog> logs,
) {
  final entries = <_TodayTimelineEntry>[
    for (var i = 0; i < snapshot.umbrellaRows.length; i++)
      _TodayTimelineEntry.action(
        sortTime: snapshot.umbrellaRows[i].umbrella.startTime,
        actionIndex: i,
      ),
    for (final log in logs)
      _TodayTimelineEntry.log(sortTime: log.loggedAt, log: log),
  ];

  entries.sort((a, b) {
    final at = a.sortTime;
    final bt = b.sortTime;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return at.compareTo(bt);
  });

  return entries;
}

List<_TodayActionStat> _statsForToday(
  TodaySnapshot snapshot,
  ModelTypeColors colors,
) {
  final byType = <int, _TodayActionStat>{};
  final dayStart = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  final dayEnd = dayStart.add(const Duration(days: 1));

  for (final row in snapshot.umbrellaRows) {
    final action = row.umbrella;
    var start = action.startTime;
    var end = action.endTime;
    if (start == null) continue;
    end ??= start.add(const Duration(hours: 1));
    if (start.isBefore(dayStart)) start = dayStart;
    if (end.isAfter(dayEnd)) end = dayEnd;
    if (!end.isAfter(start)) continue;

    final minutes = end.difference(start).inMinutes;
    if (minutes <= 0) continue;

    final id = action.modelTypeId;
    final stat = byType.putIfAbsent(
      id,
      () => _TodayActionStat(
        label:
            (action.modelTypeName != null && action.modelTypeName!.isNotEmpty)
            ? action.modelTypeName!
            : 'Type $id',
        color: colors.forId(id, name: action.modelTypeName),
      ),
    );
    stat.totalMinutes += minutes;
  }

  return byType.values.toList()
    ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
}

String _formatStatHm(int totalMinutes) {
  final h = totalMinutes ~/ 60;
  final m = totalMinutes.remainder(60);
  if (h <= 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

class _TodayStatRow extends StatelessWidget {
  const _TodayStatRow({required this.stat, required this.fraction});

  final _TodayActionStat stat;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: stat.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stat.label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.slate900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                _formatStatHm(stat.totalMinutes),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.slate500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 6, color: AppColors.slate100),
                FractionallySizedBox(
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: Container(height: 6, color: stat.color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineAddActions extends StatelessWidget {
  const _TimelineAddActions({
    required this.onAddManualTap,
    required this.onAddLogTap,
  });

  final VoidCallback? onAddManualTap;
  final VoidCallback? onAddLogTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DashedAddButton(
          label: 'Add time block manually',
          onTap: onAddManualTap,
        ),
        const SizedBox(height: 8),
        _DashedAddButton(label: 'Add log', onTap: onAddLogTap),
      ],
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
