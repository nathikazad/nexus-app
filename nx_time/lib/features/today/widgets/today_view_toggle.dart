import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/features/today/log_view_model.dart';

class TodayViewToggle extends StatelessWidget {
  const TodayViewToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final TodayViewMode mode;
  final ValueChanged<TodayViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            icon: SolarLinearIcons.running,
            tooltip: 'Actions and logs',
            selected: mode == TodayViewMode.actions,
            onTap: () => onChanged(TodayViewMode.actions),
          ),
          _ToggleButton(
            icon: SolarLinearIcons.chartSquare,
            tooltip: 'Stats',
            selected: mode == TodayViewMode.stats,
            onTap: () => onChanged(TodayViewMode.stats),
          ),
          _ToggleButton(
            icon: SolarLinearIcons.checklistMinimalistic,
            tooltip: 'Tasks',
            selected: mode == TodayViewMode.tasks,
            onTap: () => onChanged(TodayViewMode.tasks),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        shape: const CircleBorder(),
        elevation: selected ? 1 : 0,
        shadowColor: AppColors.slate200,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              icon,
              size: 18,
              color: selected ? AppColors.accent : AppColors.slate500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Uses the same pill treatment as the content toggle.
class ActionsPeriodToggle extends StatelessWidget {
  const ActionsPeriodToggle({
    super.key,
    required this.period,
    required this.onChanged,
  });

  final ActionsPeriod period;
  final ValueChanged<ActionsPeriod> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: AppColors.slate100,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final value in ActionsPeriod.values)
          Semantics(
            selected: period == value,
            button: true,
            child: Material(
              color: period == value ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              elevation: period == value ? 1 : 0,
              shadowColor: AppColors.slate200,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onChanged(value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    value == ActionsPeriod.today ? 'Today' : 'History',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: period == value
                          ? AppColors.accent
                          : AppColors.slate500,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
