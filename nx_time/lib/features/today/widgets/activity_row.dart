import 'package:flutter/material.dart';

import '../../../data/models/today_activity.dart';
import '../../../theme/app_colors.dart';

class ActivityRow extends StatelessWidget {
  const ActivityRow({
    super.key,
    required this.activity,
    this.onTap,
  });

  final TodayActivity activity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kind = activity.kind;

    Color? bg;
    if (kind == TodayActivityKind.flagged) {
      bg = AppColors.accentLight.withValues(alpha: 0.35);
    } else if (kind == TodayActivityKind.current) {
      bg = AppColors.slate50;
    }

    final border = kind == TodayActivityKind.current
        ? Border.all(color: AppColors.slate100)
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
              _BarAccent(color: activity.barColor, kind: kind),
              const SizedBox(width: 12),
              Expanded(child: _Titles(activity: activity)),
              const SizedBox(width: 8),
              _Duration(activity: activity),
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
