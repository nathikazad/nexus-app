import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/action_color_palette.dart';
import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/core/widgets/nx_tab_header.dart';
import 'package:nx_time/features/action_detail/action_detail_page.dart';
import 'package:nx_time/features/action_detail/action_detail_view_model.dart';
import 'package:nx_time/features/calendar/calendar_view_model.dart';
import 'package:nx_time/features/today/action_fold.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _weekRefDay;

  static const _sky600 = Color(0xFF0284C7);

  @override
  void initState() {
    super.initState();
    _weekRefDay = DateTime.now();
  }

  void _prevWeek() {
    setState(() {
      _weekRefDay = _weekRefDay.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    setState(() {
      _weekRefDay = _weekRefDay.add(const Duration(days: 7));
    });
  }

  String _weekRangeLabel(DateTime monday) {
    final sun = monday.add(const Duration(days: 6));
    final m = DateFormat.MMMd().format(monday);
    final s = DateFormat.MMMd().format(sun);
    return '$m – $s';
  }

  Future<void> _openDaySheet(
    BuildContext context,
    CalendarDayData dayData,
  ) async {
    final title = DateFormat.yMMMEd().format(dayData.day);
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              if (dayData.rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No actions',
                      style: TextStyle(color: AppColors.slate500),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: dayData.rows.length,
                    itemBuilder: (_, i) {
                      final row = dayData.rows[i];
                      final u = row.umbrella;
                      final bar = barColorForModelTypeId(u.modelTypeId);
                      final name = u.name.isNotEmpty ? u.name : (u.modelTypeName ?? 'Action');
                      return ListTile(
                        leading: Container(
                          width: 4,
                          height: 36,
                          decoration: BoxDecoration(
                            color: bar,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        title: Text(name),
                        subtitle: Text(
                          '${DateFormat.jm().format(u.startTime!)} – ${DateFormat.jm().format(u.endTime!)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          final args = row.children.isNotEmpty
                              ? activityDetailArgsForUmbrella(
                                  row,
                                  'Today — ${DateFormat.MMMd().format(dayData.day)}',
                                )
                              : activityDetailArgsForAction(
                                  u,
                                  'Today — ${DateFormat.MMMd().format(dayData.day)}',
                                );
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => ActivityDetailPage(args: args),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final monday = mondayOfWeek(_weekRefDay);
    final async = ref.watch(calendarWeekProvider(monday));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NxTabHeader(
          clockLabel: '9:41 AM',
          title: 'Calendar',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              IconButton(
                onPressed: _prevWeek,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(SolarLinearIcons.altArrowLeft, size: 18, color: _sky600),
              ),
              Expanded(
                child: Text(
                  _weekRangeLabel(monday),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              IconButton(
                onPressed: _nextWeek,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(SolarLinearIcons.altArrowRight, size: 18, color: _sky600),
              ),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            data: (days) {
              return ListView(
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                    child: SizedBox(
                      height: 160,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < days.length; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            Expanded(
                              child: _DayColumn(
                                dayData: days[i],
                                onTap: () => _openDaySheet(context, days[i]),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load calendar: $e')),
          ),
        ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.dayData,
    required this.onTap,
  });

  final CalendarDayData dayData;
  final VoidCallback onTap;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  int _flex(UmbrellaRow row) {
    final u = row.umbrella;
    final s = u.startTime;
    final e = u.endTime;
    if (s == null || e == null) return 1;
    final m = e.difference(s).inMinutes;
    return m <= 0 ? 1 : m;
  }

  @override
  Widget build(BuildContext context) {
    final letter = _letters[dayData.day.weekday - 1];
    final rows = dayData.rows;

    final Widget bar = rows.isEmpty
        ? Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.slate200),
              color: AppColors.slate100,
            ),
          )
        : Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.slate200),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final r in rows)
                  Expanded(
                    flex: _flex(r),
                    child: Container(
                      width: double.infinity,
                      color: barColorForModelTypeId(r.umbrella.modelTypeId),
                    ),
                  ),
              ],
            ),
          );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: bar),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              letter,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: AppColors.slate400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
