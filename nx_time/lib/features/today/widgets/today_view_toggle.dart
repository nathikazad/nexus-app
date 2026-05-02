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
            tooltip: 'Actions',
            selected: mode == TodayViewMode.actions,
            onTap: () => onChanged(TodayViewMode.actions),
          ),
          _ToggleButton(
            icon: SolarLinearIcons.notebook,
            tooltip: 'Logs',
            selected: mode == TodayViewMode.logs,
            onTap: () => onChanged(TodayViewMode.logs),
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
