import 'package:flutter/material.dart';
import 'package:nx_people/core/theme/app_theme.dart';
import 'package:nx_people/data/meeting/meeting_time.dart';

class WeekNavigator extends StatelessWidget {
  const WeekNavigator({
    super.key,
    required this.week,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });
  final DateTime week;
  final VoidCallback onPrevious, onNext, onToday;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Previous week',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left, size: 20),
        ),
        Flexible(
          child: Text(
            weekRange(week),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        IconButton(
          tooltip: 'Next week',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right, size: 20),
        ),
        const Spacer(),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.text,
            side: const BorderSide(color: AppColors.line),
            minimumSize: const Size(60, 32),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: const StadiumBorder(),
            textStyle: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontSize: 12),
          ),
          onPressed: onToday,
          child: const Text('Today'),
        ),
      ],
    ),
  );
}

class WeekDays extends StatelessWidget {
  const WeekDays({
    super.key,
    required this.week,
    required this.day,
    required this.onSelected,
  });
  final DateTime week, day;
  final ValueChanged<DateTime> onSelected;
  Widget _dayButton(BuildContext context, DateTime date) {
    final selected = DateUtils.isSameDay(date, day);
    return Semantics(
      selected: selected,
      button: true,
      label: MaterialLocalizations.of(context).formatFullDate(date),
      child: Material(
        color: selected ? const Color(0xff224a2d) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? const Color(0xff224a2d) : AppColors.line,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelected(date),
          child: SizedBox(
            height: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  const [
                    'MON',
                    'TUE',
                    'WED',
                    'THU',
                    'FRI',
                    'SAT',
                    'SUN',
                  ][date.weekday - 1],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: selected
                        ? Colors.white.withValues(alpha: .8)
                        : AppColors.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Row(
      children: [
        for (var index = 0; index < 7; index++) ...[
          if (index > 0) const SizedBox(width: 6),
          Expanded(
            child: _dayButton(
              context,
              DateTime(week.year, week.month, week.day + index),
            ),
          ),
        ],
      ],
    ),
  );
}
