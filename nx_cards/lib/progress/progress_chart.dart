import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nx_cards/progress/progress_analysis.dart';

String progressDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

class ProgressChart extends StatelessWidget {
  const ProgressChart({
    super.key,
    required this.days,
    required this.selected,
    required this.onSelected,
    required this.bucketLabel,
    this.activity = false,
  });
  final List<ProgressBucket> days;
  final int selected;
  final ValueChanged<int> onSelected;
  final String Function(ProgressBucket) bucketLabel;
  final bool activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final day = days[selected];
    final scale = MediaQuery.textScalerOf(context);
    final textScale = scale.scale(12) / 12;
    String description(ProgressBucket bucket) {
      final date =
          '${bucketLabel(bucket)}${bucket.partial ? ' · Partial' : ''}';
      final detail = activity
          ? '${bucket.recalls} recalls'
          : '${bucket.atTarget} cards · ${bucket.change > 0 ? '+' : ''}${bucket.change} net';
      return '$date\n$detail';
    }

    final tooltip = description(day);
    final style = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurface,
      height: 1.5,
      fontWeight: FontWeight.w500,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final tooltipWidth = math.min(260.0, width - 8);
        final measure = TextPainter(
          text: TextSpan(text: tooltip, style: style),
          textScaler: scale,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: tooltipWidth - 24);
        final tooltipHeight = measure.height + 16;
        measure.dispose();
        final inset = math.min(76 * textScale, width * .32);
        final plot = Rect.fromLTRB(
          inset,
          tooltipHeight + 16,
          width - 20,
          tooltipHeight + 196,
        );
        final peak = days.fold<int>(
          0,
          (v, d) => math.max(v, activity ? d.recalls : d.atTarget),
        );
        final maxY = math.max(4.0, (peak / 4).ceilToDouble() * 4);
        double x(int i) => days.length == 1
            ? plot.center.dx
            : plot.left + 14 + (plot.width - 28) * i / (days.length - 1);
        final value = activity ? day.recalls : day.atTarget;
        final barTop = plot.bottom - value / maxY * plot.height;
        void select(double dx) => onSelected(
          days.length == 1
              ? 0
              : ((dx - plot.left - 14) / (plot.width - 28) * (days.length - 1))
                    .round()
                    .clamp(0, days.length - 1),
        );
        return Semantics(
          label: activity ? 'Recall history' : 'Learning progress history',
          value: tooltip,
          increasedValue: selected < days.length - 1
              ? description(days[selected + 1])
              : null,
          decreasedValue: selected > 0 ? description(days[selected - 1]) : null,
          onIncrease: selected < days.length - 1
              ? () => onSelected(selected + 1)
              : null,
          onDecrease: selected > 0 ? () => onSelected(selected - 1) : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (e) => select(e.localPosition.dx),
            onHorizontalDragUpdate: (e) => select(e.localPosition.dx),
            child: SizedBox(
              height: plot.bottom + 35 * textScale,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      key: ValueKey(
                        activity ? 'activity-chart' : 'learning-chart',
                      ),
                      painter: _ChartPainter(
                        days: days,
                        selected: selected,
                        activity: activity,
                        plot: plot,
                        maxY: maxY,
                        scheme: scheme,
                        textScale: textScale,
                        labelStyle: theme.textTheme.bodySmall!,
                      ),
                    ),
                  ),
                  Positioned(
                    left: (x(selected) - tooltipWidth / 2).clamp(
                      4.0,
                      width - tooltipWidth - 4,
                    ),
                    top: barTop - tooltipHeight - 10,
                    width: tooltipWidth,
                    child: IgnorePointer(
                      child: Semantics(
                        liveRegion: true,
                        child: Container(
                          key: ValueKey(
                            activity ? 'recall-tooltip' : 'learning-tooltip',
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Text(
                            tooltip,
                            textAlign: TextAlign.center,
                            style: style,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.days,
    required this.selected,
    required this.activity,
    required this.plot,
    required this.maxY,
    required this.scheme,
    required this.textScale,
    required this.labelStyle,
  });
  final List<ProgressBucket> days;
  final int selected;
  final bool activity;
  final Rect plot;
  final double maxY, textScale;
  final ColorScheme scheme;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    double x(int i) => days.length == 1
        ? plot.center.dx
        : plot.left + 14 + (plot.width - 28) * i / (days.length - 1);
    double y(int v) => plot.bottom - v / maxY * plot.height;
    void label(String text, Offset position, {bool right = false}) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: labelStyle.copyWith(
            color: scheme.onSurfaceVariant,
            fontSize: 11 * textScale,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      painter.paint(
        canvas,
        Offset(right ? position.dx - painter.width : position.dx, position.dy),
      );
      painter.dispose();
    }

    for (var tick = 0; tick <= 4; tick++) {
      final cy = plot.bottom - plot.height * tick / 4;
      canvas.drawLine(
        Offset(plot.left, cy),
        Offset(plot.right, cy),
        Paint()
          ..color = scheme.outlineVariant
          ..strokeWidth = 1,
      );
      label(
        (maxY * tick / 4).toStringAsFixed(0),
        Offset(plot.left - 8, cy - 6 * textScale),
        right: true,
      );
    }
    final width = math.min(24.0, plot.width / days.length * .65);
    for (var i = 0; i < days.length; i++) {
      final top = y(activity ? days[i].recalls : days[i].atTarget);
      canvas.drawRect(
        Rect.fromLTRB(
          x(i) - width / 2,
          math.min(top, plot.bottom - 2),
          x(i) + width / 2,
          plot.bottom,
        ),
        Paint()
          ..color = scheme.primary.withValues(alpha: i == selected ? 1 : .4),
      );
    }
    String short(DateTime d) => '${d.month}/${d.day}';
    label(short(days.first.date), Offset(plot.left, plot.bottom + 10));
    if (days.length > 1) {
      label(
        short(days.last.date),
        Offset(plot.right, plot.bottom + 10),
        right: true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => true;
}
