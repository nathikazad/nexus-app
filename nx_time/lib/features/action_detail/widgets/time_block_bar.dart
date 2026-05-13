import 'package:flutter/material.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/features/action_detail/action_detail_view_model.dart';

/// Start / duration / end row for the time block.
class TimeBlockBar extends StatelessWidget {
  const TimeBlockBar({super.key, required this.args});

  final ActivityDetailArgs args;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TimeColumn(
              label: 'start',
              time: args.startTime,
              suffix: args.startSuffix,
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Divider(height: 1, color: AppColors.slate200),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      args.durationCenter,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.slate400,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(height: 1, color: AppColors.slate200),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _TimeColumn(
              label: 'end',
              time: args.endTime,
              suffix: args.endSuffix,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({
    required this.label,
    required this.time,
    required this.suffix,
  });

  final String label;
  final String time;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.slate400),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.slate900,
            ),
            children: [
              TextSpan(text: time),
              TextSpan(
                text: suffix,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.slate500,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
