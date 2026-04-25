import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/sprint/sprint_state.dart';
import 'package:nx_projects/features/sprint/sprint_view_model.dart';

/// `reference/desktop/styles.css` `.sprint-summary`
class SprintSummaryStrip extends StatelessWidget {
  const SprintSummaryStrip({
    super.key,
    required this.sprint,
    required this.stats,
    required this.scheduledH,
    required this.unscheduledH,
  });

  final Sprint sprint;
  final SprintHeaderStats stats;
  final double scheduledH;
  final double unscheduledH;

  @override
  Widget build(BuildContext context) {
    final phase = switch (sprint.state) {
      SprintState.active => 'In flight — mid-sprint',
      SprintState.planned => 'Planning',
      SprintState.done => 'Done',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _Stat(
            label: 'Scheduled',
            value: '${_fmt(scheduledH)}h',
            valueStyle: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500),
          ),
          const _VertDivider(),
          _Stat(
            label: 'Unsched.',
            value: '${_fmt(unscheduledH)}h',
            valueStyle: TextStyle(
              color: unscheduledH > 0 ? AppColors.warn : AppColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
          const _VertDivider(),
          _Stat(
            label: 'Load',
            value: stats.pct == 0 ? '—' : '${stats.pct}%',
            valueStyle: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500),
            sub: 'of cap',
          ),
          const Spacer(),
          Text(
            phase,
            style: const TextStyle(fontSize: 11, color: AppColors.muted, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  String _fmt(double h) {
    if (h == h.roundToDouble()) {
      return h.toInt().toString();
    }
    return h.toStringAsFixed(1);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.valueStyle, this.sub});

  final String label;
  final String value;
  final TextStyle valueStyle;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.dim,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: value, style: valueStyle),
              if (sub != null) TextSpan(text: ' $sub', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  const _VertDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.border,
    );
  }
}
