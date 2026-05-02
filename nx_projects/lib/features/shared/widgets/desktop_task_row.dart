import 'package:flutter/material.dart';

import 'package:nx_projects/core/formatting/hours_format.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/theme/kind_color_palette.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/domain/task/task_severity.dart';
import 'package:nx_projects/domain/task/task_status.dart';

/// Dense desktop backlog row: matches `reference/desktop/styles.css` `.row` grid
/// (rank · glyph · kind · crumb · title · est · sprint chip · ⋮).
class DesktopTaskRow extends StatefulWidget {
  const DesktopTaskRow({
    super.key,
    required this.task,
    required this.rankLabel,
    this.crumb,
    this.sprintChipLabel,
    this.isSearchMatch = false,
    this.isLocated = false,
    this.onMenu,
    this.onRowTap,
  });

  final Task task;
  final String rankLabel;

  /// When true, tints the row and title to mirror reference `.row.match` while searching.
  final bool isSearchMatch;

  /// Temporary cross-panel locator highlight from the sprint cart.
  final bool isLocated;

  /// Replaces the default [Text] for [task.crumb] (e.g. bucket pill in Projects tree).
  final Widget? crumb;

  /// Shown in the sprint column: sprint-name abbreviation, or `☆` when unscheduled.
  final String? sprintChipLabel;

  final VoidCallback? onMenu;
  final VoidCallback? onRowTap;

  @override
  State<DesktopTaskRow> createState() => _DesktopTaskRowState();
}

class _DesktopTaskRowState extends State<DesktopTaskRow> {
  bool _hover = false;

  static const double _kNarrowMaxWidth = 640;

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final done = t.status == TaskStatus.done;
    final highlighted = widget.isSearchMatch || widget.isLocated;
    final String glyph;
    if (t.kind == TaskKind.bug) {
      glyph = '●';
    } else if (t.kind == TaskKind.feat) {
      glyph = '◉';
    } else {
      glyph = '▢';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < _kNarrowMaxWidth;
        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onRowTap ?? widget.onMenu,
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: highlighted
                      ? const Color(0x10FBBF24)
                      : (_hover ? AppColors.panel : null),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: highlighted
                        ? const Color(0x59FBBF24)
                        : (_hover ? AppColors.border : Colors.transparent),
                  ),
                ),
                child: narrow
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 700,
                          child: _rowInner(glyph: glyph, done: done),
                        ),
                      )
                    : _rowInner(glyph: glyph, done: done),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Narrow mode wraps this in a [SizedBox(width: 700)] + horizontal scroll;
  /// wide mode lets the [Expanded] title use full pane width.
  Widget _rowInner({required String glyph, required bool done}) {
    final t = widget.task;
    final match = widget.isSearchMatch || widget.isLocated;
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            widget.rankLabel,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              color: done ? AppColors.dim : AppColors.dim,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 18,
          child: Text(
            glyph,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: done ? AppColors.dim : kindColor(t.kind),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Reference `.row .kind`: fixed grid column, badge `justify-self: start` (hug
        // content, not full column width).
        SizedBox(
          width: 56,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _KindPill(kind: t.kind, dim: done),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 200,
          child: DefaultTextStyle(
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
            child:
                widget.crumb ??
                (t.crumb.isEmpty
                    ? const SizedBox.shrink()
                    : Text(
                        t.crumb,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: t.title,
                  style: TextStyle(
                    fontSize: 13,
                    color: (match && !done)
                        ? AppColors.warn
                        : (done ? AppColors.muted : AppColors.text),
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (t.severity != null) ...[
                  const WidgetSpan(child: SizedBox(width: 6)),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: _SevPill(severity: t.severity!),
                  ),
                ],
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: Text(
            formatHours(t.estimate),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              color: done ? AppColors.dim : AppColors.muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: _SprintChip(
            label: widget.sprintChipLabel ?? '☆',
            sprintId: t.sprintId,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 18,
          child: Opacity(
            opacity: _hover ? 1 : 0,
            child: InkWell(
              onTap: widget.onMenu,
              child: const Text(
                '⋮',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1, color: AppColors.dim),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KindPill extends StatelessWidget {
  const _KindPill({required this.kind, required this.dim});

  final TaskKind kind;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(
          color: dim
              ? AppColors.border
              : (kind == TaskKind.feat
                    ? const Color(0x4D6AA3FF)
                    : kind == TaskKind.bug
                    ? const Color(0x4DF87171)
                    : AppColors.border),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        kindLabel(kind).toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 0.4,
          color: dim ? AppColors.dim : kindColor(kind),
        ),
      ),
    );
  }
}

class _SevPill extends StatelessWidget {
  const _SevPill({required this.severity});

  final TaskSeverity severity;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (severity) {
      TaskSeverity.crit => (const Color(0x26F87171), AppColors.crit),
      TaskSeverity.med => (const Color(0x26FBBF24), AppColors.warn),
      TaskSeverity.low => (AppColors.panel2, AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(switch (severity) {
        TaskSeverity.crit => 'crit',
        TaskSeverity.med => 'med',
        TaskSeverity.low => 'low',
      }, style: TextStyle(fontSize: 10, color: fg)),
    );
  }
}

class _SprintChip extends StatelessWidget {
  const _SprintChip({required this.label, required this.sprintId});

  final String label;
  final int? sprintId;

  @override
  Widget build(BuildContext context) {
    final isStar = label == '☆';
    final s14 = sprintId == 14;
    final s15 = sprintId == 15;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: s14
            ? const Color(0x1E6AA3FF)
            : s15
            ? const Color(0x1AC084FC)
            : Colors.transparent,
        border: Border.all(
          color: isStar
              ? AppColors.border
              : s14
              ? const Color(0x596AA3FF)
              : s15
              ? const Color(0x59C084FC)
              : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.4,
            color: isStar
                ? AppColors.dim
                : (s14 ? AppColors.accent : AppColors.text),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Sprint column label: first char + last two chars of sprint name, else `☆`.
String desktopSprintChipLabelForTask(
  Task t, [
  List<Sprint> sprints = const [],
]) {
  if (t.sprintId == null) return '☆';
  for (final sprint in sprints) {
    if (sprint.id == t.sprintId) {
      return _shortSprintName(sprint.name);
    }
  }
  return 'S${t.sprintId}';
}

String _shortSprintName(String name) {
  final compact = name.replaceAll(RegExp(r'\s+'), '');
  if (compact.length <= 3) return compact;
  return '${compact[0]}${compact.substring(compact.length - 2)}';
}
