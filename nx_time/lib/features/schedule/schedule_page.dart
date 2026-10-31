import 'package:nx_time/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/core/widgets/nx_tab_header.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:nx_time/domain/schedules/schedule_plan.dart';

final scheduleInitialDateProvider = Provider<DateTime>((ref) => DateTime.now());
final schedulePlansProvider = FutureProvider.autoDispose<List<SchedulePlan>>((
  ref,
) async {
  final workspace = await ref.watch(timeDomainsProvider.future);
  final groups = await Future.wait(
    workspace.selectedIds.map((id) async {
      final rows = await fetchKgqlModels(
        workspace.clients[id]!,
        domainId: id,
        filter: {'model_type': 'Schedule'},
        struct: {
          'id': true,
          'name': true,
          'entries': true,
          'Routine': {
            'name': true,
            'Goal': {'id': true},
            'id': true,
            'start_date': true,
            'end_date': true,
            'model_type': true,
            'filter': true,
          },
        },
      );
      return rows
          .map(
            (m) => SchedulePlan.fromModel(
              m,
              domainName: workspace.selectedIds.length > 1
                  ? workspace.name(id)
                  : null,
            ),
          )
          .toList();
    }),
  );
  return groups.expand((g) => g).toList();
});

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});
  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  late DateTime day;
  @override
  void initState() {
    super.initState();
    final d = ref.read(scheduleInitialDateProvider);
    day = DateTime(d.year, d.month, d.day);
  }

  void move(int n) =>
      setState(() => day = DateTime(day.year, day.month, day.day + n));
  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(schedulePlansProvider);
    final colors = modelTypeColorsOrFallback(
      ref.watch(modelTypeColorsProvider),
    );
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          NxTabHeader(
            title: 'Schedule',
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(
                Icons.arrow_back,
                size: 22,
                color: AppColors.slate600,
              ),
            ),
            trailing: const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous day',
                  onPressed: () => move(-1),
                  icon: const Icon(
                    Icons.chevron_left,
                    color: AppColors.slate400,
                  ),
                ),
                Expanded(
                  child: Text(
                    DateFormat('EEE, MMM d, yyyy').format(day),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next day',
                  onPressed: () => move(1),
                  icon: const Icon(
                    Icons.chevron_right,
                    color: AppColors.slate400,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: plans.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load schedule'),
                    TextButton(
                      onPressed: () => ref.invalidate(schedulePlansProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (rows) {
                final windows = rows.expand((p) => p.onDay(day)).toList()
                  ..sort((a, b) => a.start.compareTo(b.start));
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(schedulePlansProvider);
                    await ref.read(schedulePlansProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (windows.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'Nothing scheduled for this day.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.slate500,
                            ),
                          ),
                        ),
                      for (final window in windows)
                        ScheduleWindowRow(
                          window: window,
                          activityColor: window.plan.modelType == null
                              ? null
                              : colors.forActivity(
                                  window.plan.modelType,
                                  filter: window.plan.goalFilter,
                                ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ScheduleWindowRow extends StatelessWidget {
  const ScheduleWindowRow({
    super.key,
    required this.window,
    this.activityColor,
    this.title,
  });
  final Color? activityColor;
  final String? title;
  final PlanWindow window;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
    decoration: BoxDecoration(
      border: Border(
        bottom: const BorderSide(color: AppColors.slate100),
        left: BorderSide(color: activityColor ?? Colors.transparent, width: 2),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title ?? window.plan.name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: activityColor ?? AppColors.slate900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${DateFormat('h:mm a').format(window.start)} – ${DateFormat('h:mm a').format(window.end)}${DateUtils.isSameDay(window.start, window.end) ? '' : ' · next day'}',
          style: const TextStyle(fontSize: 12, color: AppColors.slate500),
        ),
        if (window.plan.domainName != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              window.plan.domainName!,
              style: const TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
          ),
      ],
    ),
  );
}
