import 'package:flutter/material.dart';

import 'package:nx_projects/core/formatting/sprint_variance.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/sprint/sprint_state.dart';

/// `reference/desktop/styles.css` `.sprint-summary`
class SprintSummaryStrip extends StatelessWidget {
  const SprintSummaryStrip({
    super.key,
    required this.sprint,
    required this.nDone,
    required this.nTotal,
    required this.actualH,
    required this.plannedH,
    required this.driftCount,
    required this.blockedCount,
  });

  final Sprint sprint;
  final int nDone;
  final int nTotal;
  final double actualH;
  final double plannedH;
  final int driftCount;
  final int blockedCount;

  @override
  Widget build(BuildContext context) {
    final phase = switch (sprint.state) {
      SprintState.active => 'In flight — mid-sprint',
      SprintState.planned => 'Planning',
      SprintState.done => 'Done',
    };
    final allDone = nTotal > 0 && nDone == nTotal;
    final hoursValColor = varianceColorForPair(actualH, plannedH);
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
            label: 'Done',
            value: nTotal == 0 ? '—' : '$nDone/$nTotal',
            valueStyle: TextStyle(
              color: allDone ? AppColors.ok : AppColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
          const _VertDivider(),
          _Stat(
            label: 'Hours',
            value: '${_fmt(actualH)}/${_fmt(plannedH)}h',
            valueStyle: TextStyle(
              color: hoursValColor,
              fontWeight: FontWeight.w500,
            ),
            sub: 'act / pln',
          ),
          const _VertDivider(),
          _Stat(
            label: 'Drift',
            value: '$driftCount',
            valueStyle: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (blockedCount > 0) ...[
            const _VertDivider(),
            _Stat(
              label: 'Blocked',
              value: '$blockedCount',
              valueStyle: const TextStyle(
                color: AppColors.warn,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const Spacer(),
          Text(
            phase,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.muted,
              fontStyle: FontStyle.italic,
            ),
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
              if (sub != null)
                TextSpan(
                  text: ' $sub',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
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
