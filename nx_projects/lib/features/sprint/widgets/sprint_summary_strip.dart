import 'package:flutter/material.dart';

import 'package:nx_projects/core/formatting/sprint_variance.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/sprint/sprint_state.dart';

/// `reference/desktop/styles.css` `.sprint-summary`
class SprintSummaryStrip extends StatelessWidget {
  SprintSummaryStrip({
    super.key,
    required this.sprint,
    required this.nDone,
    required this.nTotal,
    required this.actualH,
    required this.plannedH,
    required this.driftCount,
    required this.blockedCount,
    required this.doingCount,
    required this.dayIndex,
  });

  final Sprint sprint;
  final int nDone;
  final int nTotal;
  final double actualH;
  final double plannedH;
  final int driftCount;
  final int blockedCount;
  final int doingCount;
  final int dayIndex;

  @override
  Widget build(BuildContext context) {
    final phase = switch (sprint.state) {
      SprintState.active =>
        'Day $dayIndex of ${sprint.length} · $doingCount in flight',
      SprintState.planned => 'Not started — planning only',
      SprintState.done => 'Sprint complete',
    };
    final allDone = nTotal > 0 && nDone == nTotal;
    final hoursValColor = varianceColorForPair(context, actualH, plannedH);
    return Container(
      margin: EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.panel2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          _Stat(
            label: 'Done',
            value: nTotal == 0 ? '—' : '$nDone/$nTotal',
            sub: nTotal == 0 ? null : 'items',
            valueStyle: TextStyle(
              color: allDone ? context.colors.ok : context.colors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
          _VertDivider(),
          _Stat(
            label: 'Hours actual / planned',
            value: '${_fmt(actualH)}h',
            valueStyle: TextStyle(
              color: hoursValColor,
              fontWeight: FontWeight.w500,
            ),
            sub: '/ ${_fmt(plannedH)}h',
          ),
          _VertDivider(),
          _Stat(
            label: 'Drift',
            value: '$driftCount',
            sub: 'item${driftCount == 1 ? '' : 's'} moved',
            valueStyle: TextStyle(
              color: context.colors.warn,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (blockedCount > 0) ...[
            _VertDivider(),
            _Stat(
              label: 'Blocked',
              value: '$blockedCount',
              valueStyle: TextStyle(
                color: context.colors.warn,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          Spacer(),
          Text(
            phase,
            style: TextStyle(
              fontSize: 11,
              color: context.colors.muted,
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
  _Stat({
    required this.label,
    required this.value,
    required this.valueStyle,
    this.sub,
  });

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
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            color: context.colors.dim,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: value, style: valueStyle),
              if (sub != null)
                TextSpan(
                  text: ' $sub',
                  style: TextStyle(
                    color: context.colors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
          style: TextStyle(
            fontSize: 12,
            color: context.colors.text,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  _VertDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: EdgeInsets.symmetric(horizontal: 20),
      color: context.colors.border,
    );
  }
}
