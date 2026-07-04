import 'package:flutter/material.dart' hide Action;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/log/daily_log.dart';
import 'package:nx_time/features/action_detail/action_detail_page.dart';
import 'package:nx_time/features/action_detail/action_detail_view_model.dart';
import 'package:nx_time/features/log_edit/log_edit_page.dart';
import 'package:nx_time/features/today/log_view_model.dart';
import 'package:nx_time/features/today/today_view_model.dart';
import 'package:nx_time/features/today/widgets/activity_row.dart';
import 'package:nx_time/features/today/widgets/log_row.dart';
import 'package:nx_time/features/today/widgets/time_map_bar.dart';

class DayActionsPage extends ConsumerWidget {
  const DayActionsPage({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d0 = DateTime(date.year, date.month, date.day);
    final snapshotAsync = ref.watch(dayActionsSnapshotProvider(d0));
    final colors = modelTypeColorsOrFallback(
      ref.watch(modelTypeColorsProvider),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: snapshotAsync.when(
          data: (snapshot) =>
              _DayActionsBody(date: d0, snapshot: snapshot, colors: colors),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load actions: $e',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.slate500),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayActionsBody extends StatelessWidget {
  const _DayActionsBody({
    required this.date,
    required this.snapshot,
    required this.colors,
  });

  final DateTime date;
  final TodaySnapshot snapshot;
  final ModelTypeColors colors;

  void _openActivity(BuildContext context, int index) {
    final row = index < snapshot.umbrellaRows.length
        ? snapshot.umbrellaRows[index]
        : null;
    final rowAction = index < snapshot.sourceActions.length
        ? snapshot.sourceActions[index]
        : null;
    late final ActivityDetailArgs args;
    if (row != null && row.children.isNotEmpty) {
      args = activityDetailArgsForUmbrella(row, snapshot.dayDateLabel, colors);
    } else if (rowAction != null) {
      args = activityDetailArgsForAction(
        rowAction,
        snapshot.dayDateLabel,
        colors,
      );
    } else {
      args = activityDetailArgsForTodayRow(
        snapshot.actions[index],
        snapshot.dayDateLabel,
      );
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => ActivityDetailPage(args: args)),
    );
  }

  void _openChild(BuildContext context, int rowIndex, int childIndex) {
    if (rowIndex < 0 || rowIndex >= snapshot.umbrellaRows.length) {
      return;
    }
    final row = snapshot.umbrellaRows[rowIndex];
    if (childIndex < 0 || childIndex >= row.children.length) {
      return;
    }
    final child = row.children[childIndex];
    final args = activityDetailArgsForAction(
      child,
      snapshot.dayDateLabel,
      colors,
    );
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => ActivityDetailPage(args: args)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = DateFormat('EEEE, MMM d').format(date);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back, size: 20),
                          color: AppColors.slate600,
                          tooltip: 'Back',
                        ),
                      ),
                      const Text(
                        'Actions',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate900,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TimeMapBar(
                    segments: snapshot.timeMapSegments,
                    currentMarkerFraction: snapshot.currentMarkerFraction,
                    showCurrentMarker: _isSameDate(date, DateTime.now()),
                  ),
                ),
              ],
            ),
          ),
        ),
        _DayTimelineSliver(
          date: date,
          snapshot: snapshot,
          onActivityTap: (index) => _openActivity(context, index),
          onChildTap: (rowIndex, childIndex) =>
              _openChild(context, rowIndex, childIndex),
        ),
      ],
    );
  }
}

class _DayTimelineSliver extends ConsumerWidget {
  const _DayTimelineSliver({
    required this.date,
    required this.snapshot,
    required this.onActivityTap,
    required this.onChildTap,
  });

  final DateTime date;
  final TodaySnapshot snapshot;
  final void Function(int index) onActivityTap;
  final void Function(int rowIndex, int childIndex) onChildTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(dailyLogsForDayProvider(date));

    return logsAsync.when(
      data: (logs) {
        final entries = _dayTimelineEntries(snapshot, logs);
        if (entries.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No actions or logs',
                style: TextStyle(fontSize: 14, color: AppColors.slate500),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          sliver: SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final log = entry.log;
              if (log != null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LogRow(
                    log: log,
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              LogEditPage(mode: LogEditMode.edit, initial: log),
                        ),
                      );
                    },
                  ),
                );
              }
              final rowIndex = entry.actionIndex!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ActivityRow(
                  activity: snapshot.actions[rowIndex],
                  onTap: () => onActivityTap(rowIndex),
                  onChildTap: (childIndex) => onChildTap(rowIndex, childIndex),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load logs: $e',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.slate500),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayTimelineEntry {
  const _DayTimelineEntry.action({
    required this.sortTime,
    required this.order,
    required this.actionIndex,
  }) : log = null;

  const _DayTimelineEntry.log({
    required this.sortTime,
    required this.order,
    required this.log,
  }) : actionIndex = null;

  final DateTime? sortTime;
  final int order;
  final int? actionIndex;
  final DailyLog? log;
}

List<_DayTimelineEntry> _dayTimelineEntries(
  TodaySnapshot snapshot,
  List<DailyLog> logs,
) {
  final entries = <_DayTimelineEntry>[
    for (var i = 0; i < snapshot.umbrellaRows.length; i++)
      _DayTimelineEntry.action(
        sortTime: snapshot.umbrellaRows[i].umbrella.startTime,
        order: i * 2,
        actionIndex: i,
      ),
    for (var i = 0; i < logs.length; i++)
      _DayTimelineEntry.log(
        sortTime: logs[i].loggedAt,
        order: i * 2 + 1,
        log: logs[i],
      ),
  ];

  entries.sort((a, b) {
    final at = a.sortTime;
    final bt = b.sortTime;
    if (at == null && bt == null) {
      return a.order.compareTo(b.order);
    }
    if (at == null) {
      return 1;
    }
    if (bt == null) {
      return -1;
    }
    final cmp = at.compareTo(bt);
    if (cmp != 0) {
      return cmp;
    }
    return a.order.compareTo(b.order);
  });
  return entries;
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
