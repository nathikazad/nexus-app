import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/features/today/today_view_model.dart';

class ActivityRow extends StatefulWidget {
  const ActivityRow({
    super.key,
    required this.activity,
    this.onTap,
    this.onChildTap,
  });

  final TodayActivity activity;
  final VoidCallback? onTap;

  /// Called with child index when a row in an expanded umbrella is tapped.
  final void Function(int childIndex)? onChildTap;

  @override
  State<ActivityRow> createState() => _ActivityRowState();
}

class _ActivityRowState extends State<ActivityRow> {
  bool _expanded = false;

  TodayUmbrellaActivity? get _umbrella =>
      widget.activity is TodayUmbrellaActivity ? widget.activity as TodayUmbrellaActivity : null;

  @override
  Widget build(BuildContext context) {
    final umbrella = _umbrella;
    final kind = widget.activity.kind;

    Color? bg;
    if (kind == TodayActivityKind.flagged) {
      bg = AppColors.accentLight.withValues(alpha: 0.35);
    } else if (kind == TodayActivityKind.current) {
      bg = AppColors.slate50;
    }

    final border = kind == TodayActivityKind.current
        ? Border.all(color: AppColors.slate100)
        : null;

    final showChevron = umbrella != null && umbrella.children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(16),
                      border: border,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BarAccent(color: widget.activity.barColor, kind: kind),
                        const SizedBox(width: 12),
                        Expanded(child: _Titles(activity: widget.activity)),
                        const SizedBox(width: 8),
                        _Duration(activity: widget.activity),
                      ],
                    ),
                  ),
                ),
              ),
              if (showChevron)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: IconButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded
                          ? SolarLinearIcons.altArrowUp
                          : SolarLinearIcons.altArrowDown,
                      size: 20,
                      color: AppColors.slate400,
                    ),
                    tooltip: _expanded ? 'Collapse' : 'Expand',
                  ),
                ),
            ],
          ),
        ),
        if (umbrella != null && _expanded && umbrella.children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 28, right: 12, top: 4, bottom: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.slate100, width: 1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  children: [
                    for (var i = 0; i < umbrella.children.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _UmbrellaChildTile(
                          activity: umbrella.children[i],
                          onTap: widget.onChildTap != null
                              ? () => widget.onChildTap!(i)
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UmbrellaChildTile extends StatelessWidget {
  const _UmbrellaChildTile({
    required this.activity,
    this.onTap,
  });

  final TodayActivity activity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: activity.barColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${activity.timeRangeLabel} · ${activity.durationLabel}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarAccent extends StatelessWidget {
  const _BarAccent({required this.color, required this.kind});

  final Color color;
  final TodayActivityKind kind;

  @override
  Widget build(BuildContext context) {
    if (kind == TodayActivityKind.current) {
      return SizedBox(
        width: 12,
        height: 40,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      );
    }
    return Container(
      width: 4,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _Titles extends StatelessWidget {
  const _Titles({required this.activity});

  final TodayActivity activity;

  @override
  Widget build(BuildContext context) {
    if (activity.kind == TodayActivityKind.flagged) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                activity.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accent,
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            activity.timeRangeLabel,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.slate500,
            ),
          ),
        ],
      );
    }

    if (activity.kind == TodayActivityKind.current) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activity.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.slate900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          const Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 12, color: AppColors.slate500),
              children: [
                TextSpan(text: '9:45a – '),
                TextSpan(
                  text: 'now',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activity.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.slate900,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          activity.timeRangeLabel,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.slate500,
          ),
        ),
      ],
    );
  }
}

class _Duration extends StatelessWidget {
  const _Duration({required this.activity});

  final TodayActivity activity;

  @override
  Widget build(BuildContext context) {
    if (activity.kind == TodayActivityKind.current && activity.liveElapsedLabel != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          activity.liveElapsedLabel!,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.accent,
            letterSpacing: -0.2,
          ),
        ),
      );
    }
    return Text(
      activity.durationLabel,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.slate400,
      ),
    );
  }
}
