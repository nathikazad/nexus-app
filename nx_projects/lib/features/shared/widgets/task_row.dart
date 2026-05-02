import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/theme/bucket_color_palette.dart';
import 'package:nx_projects/core/theme/kind_color_palette.dart';
import 'package:nx_projects/core/theme/status_color_palette.dart';
import 'package:nx_projects/core/formatting/hours_format.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/domain/task/task_severity.dart';
import 'package:nx_projects/domain/task/task_status.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';

class TaskRow extends StatelessWidget {
  TaskRow({
    super.key,
    required this.task,
    this.showCrumb = true,
    this.showBucket = false,
    this.showStatus = false,
    this.onMenu,
  });

  final Task task;
  final bool showCrumb;
  final bool showBucket;
  final bool showStatus;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.done;
    final String glyph;
    if (task.kind == TaskKind.bug) {
      glyph = '●';
    } else if (task.kind == TaskKind.feat) {
      glyph = '◉';
    } else {
      glyph = '▢';
    }

    return Material(
      color: context.colors.panel,
      child: InkWell(
        onTap: onMenu,
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  glyph,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    color: done
                        ? context.colors.dim
                        : kindColor(context, task.kind),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: task.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: done
                                  ? context.colors.muted
                                  : context.colors.text,
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (task.severity != null) ...[
                            TextSpan(text: ' '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: _SevPill(severity: task.severity!),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _KindChip(kind: task.kind),
                        if (showStatus && task.status != TaskStatus.todo)
                          _StatusPill(status: task.status),
                        if (showCrumb && task.crumb.isNotEmpty)
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 200),
                            child: Text(
                              task.crumb,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.colors.muted,
                              ),
                            ),
                          ),
                        if (showBucket) _BucketPill(task: task),
                        Text(
                          formatHours(task.estimate),
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.muted,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onMenu,
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: context.colors.dim,
                ),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SevPill extends StatelessWidget {
  _SevPill({required this.severity});

  final TaskSeverity severity;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (severity) {
      TaskSeverity.crit => (Color(0x26F87171), context.colors.crit),
      TaskSeverity.med => (Color(0x26FBBF24), context.colors.warn),
      TaskSeverity.low => (context.colors.panel2, context.colors.muted),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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

class _KindChip extends StatelessWidget {
  _KindChip({required this.kind});

  final TaskKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(
          color: kind == TaskKind.feat
              ? Color(0x4D6AA3FF)
              : kind == TaskKind.bug
              ? Color(0x4DF87171)
              : context.colors.border,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        kindLabel(kind).toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 0.4,
          color: kindColor(context, kind),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  _StatusPill({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final bg = statusBackground(context, status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        border: bg == null ? Border.all(color: context.colors.border) : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: statusForeground(context, status),
        ),
      ),
    );
  }
}

class _BucketPill extends StatelessWidget {
  _BucketPill({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final b = task.bucket;
    if (b == TaskBucket.unsorted) {
      return Text(
        'unsorted',
        style: TextStyle(
          fontSize: 10,
          fontStyle: FontStyle.italic,
          color: context.colors.dim,
        ),
      );
    }
    return Text(
      b.name,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: bucketColor(context, b),
      ),
    );
  }
}
