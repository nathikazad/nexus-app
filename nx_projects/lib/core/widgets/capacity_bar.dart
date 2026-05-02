import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';

/// Stacked bar: done / doing / blocked / todo — segment widths = hours in status / [capH].
class CapacityBar extends StatelessWidget {
  CapacityBar({
    super.key,
    required this.todoH,
    required this.doingH,
    required this.blockedH,
    required this.doneH,
    required this.capH,
  });

  final double todoH;
  final double doingH;
  final double blockedH;
  final double doneH;
  final double capH;

  @override
  Widget build(BuildContext context) {
    final cap = capH <= 0 ? 1.0 : capH;
    int flex(double h) {
      if (h <= 0) return 0;
      return (h * 1000 / cap).round().clamp(1, 1000000);
    }

    final children = <Widget>[];
    void add(Widget c, int f) {
      if (f > 0) children.add(Expanded(flex: f, child: c));
    }

    add(
      ColoredBox(color: context.colors.ok, child: SizedBox(height: 6)),
      flex(doneH),
    );
    add(
      ColoredBox(color: context.colors.accent, child: SizedBox(height: 6)),
      flex(doingH),
    );
    add(
      ColoredBox(color: context.colors.warn, child: SizedBox(height: 6)),
      flex(blockedH),
    );
    add(
      ColoredBox(color: context.colors.border2, child: SizedBox(height: 6)),
      flex(todoH),
    );

    if (children.isEmpty) {
      return SizedBox(height: 6);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Row(children: children),
    );
  }
}

/// For daily view: done / doing / (todo+blocked) as stacked segments of total work.
class DailyProgressBar extends StatelessWidget {
  DailyProgressBar({
    super.key,
    required this.todoH,
    required this.doingH,
    required this.blockedH,
    required this.doneH,
  });

  final double todoH;
  final double doingH;
  final double blockedH;
  final double doneH;

  @override
  Widget build(BuildContext context) {
    final total = doneH + doingH + blockedH + todoH;
    if (total <= 0) {
      return SizedBox(height: 6);
    }
    int flex(double h) {
      if (h <= 0) return 0;
      return (h * 1000 / total).round().clamp(1, 1000000);
    }

    final children = <Widget>[];
    void add(Widget c, int f) {
      if (f > 0) children.add(Expanded(flex: f, child: c));
    }

    add(
      ColoredBox(color: context.colors.ok, child: SizedBox(height: 6)),
      flex(doneH),
    );
    add(
      ColoredBox(color: context.colors.accent, child: SizedBox(height: 6)),
      flex(doingH),
    );
    add(
      ColoredBox(color: context.colors.border2, child: SizedBox(height: 6)),
      flex(todoH + blockedH),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Row(children: children),
    );
  }
}

/// Per-day cap fill: [dayH] / [dailyCap].
class DayCapBar extends StatelessWidget {
  DayCapBar({
    super.key,
    required this.ratio,
    this.isOver = false,
    this.height = 4,
  });

  final double ratio;
  final bool isOver;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            ColoredBox(color: context.colors.panel3, child: SizedBox.expand()),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratio.clamp(0, 1),
                child: ColoredBox(
                  color: isOver ? context.colors.warn : context.colors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
