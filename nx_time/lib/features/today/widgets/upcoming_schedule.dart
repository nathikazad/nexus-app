import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/schedules/schedule_plan.dart';
import 'package:nx_time/features/schedule/schedule_page.dart';

List<PlanWindow> upcomingScheduleWindows(
  List<SchedulePlan> plans,
  DateTime now,
) =>
    plans
        .expand((plan) => plan.onDay(now))
        .where((window) => !window.start.isBefore(now))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

class UpcomingSchedule extends ConsumerStatefulWidget {
  const UpcomingSchedule({super.key});
  @override
  ConsumerState<UpcomingSchedule> createState() => _UpcomingScheduleState();
}

class _UpcomingScheduleState extends ConsumerState<UpcomingSchedule>
    with WidgetsBindingObserver {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(schedulePlansProvider);
    final colors = modelTypeColorsOrFallback(
      ref.watch(modelTypeColorsProvider),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Later today',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.slate500,
          ),
        ),
        const SizedBox(height: 8),
        plans.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => TextButton(
            onPressed: () => ref.invalidate(schedulePlansProvider),
            child: const Text('Could not load schedule · Retry'),
          ),
          data: (plans) {
            final windows = upcomingScheduleWindows(plans, DateTime.now());
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (windows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Nothing else scheduled today.',
                      style: TextStyle(fontSize: 13, color: AppColors.slate400),
                    ),
                  ),
                for (final window in windows)
                  ScheduleWindowRow(
                    window: window,
                    title: window.plan.modelType ?? window.plan.name,
                    activityColor: window.plan.modelType == null
                        ? null
                        : colors.forActivity(
                            window.plan.modelType,
                            filter: window.plan.goalFilter,
                          ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
