import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/app_theme.dart';
import 'package:nx_time/core/widgets/nx_tab_header.dart';

class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});

  static const _clock = '9:41 AM';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NxTabHeader(
          clockLabel: _clock,
          title: 'Goals',
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.slate100)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(
                leading: '5',
                leadingColor: AppColors.goalOnTrack,
                rest: 'on track',
              ),
              _SummaryChip(
                leading: '2',
                leadingColor: AppColors.goalAtRisk,
                rest: 'at risk',
              ),
              _SummaryChip(
                leading: '1',
                leadingColor: AppColors.goalMissed,
                rest: 'missed',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            children: [
              const SizedBox(height: 10),
              _SectionLabel(text: 'Daily goals'),
              _GoalRow(
                title: 'Wake up before 7am',
                status: '6:48 today',
                statusColor: AppColors.goalOnTrack,
                dots: const [
                  _Dot.ok,
                  _Dot.ok,
                  _Dot.miss,
                  _Dot.ok,
                  _Dot.ok,
                  _Dot.todayOk,
                  _Dot.pend,
                ],
              ),
              _GoalRow(
                title: 'Sleep by 11pm',
                status: '11:42 last night',
                statusColor: AppColors.goalMissed,
                dots: const [
                  _Dot.ok,
                  _Dot.miss,
                  _Dot.ok,
                  _Dot.ok,
                  _Dot.miss,
                  _Dot.todayMiss,
                  _Dot.pend,
                ],
              ),
              _GoalRow(
                title: 'Sleep 8 hours',
                status: '6h 50m today',
                statusColor: AppColors.goalMissed,
                dots: const [
                  _Dot.ok,
                  _Dot.ok,
                  _Dot.miss,
                  _Dot.ok,
                  _Dot.miss,
                  _Dot.todayMiss,
                  _Dot.pend,
                ],
                subline: 'Today: 6h 50m of 8h',
                progress: 0.85,
                progressColor: AppColors.dotMiss,
              ),
              _GoalRow(
                title: 'Yoga every day',
                status: '32m today',
                statusColor: AppColors.goalOnTrack,
                dots: const [
                  _Dot.ok,
                  _Dot.miss,
                  _Dot.ok,
                  _Dot.miss,
                  _Dot.ok,
                  _Dot.todayOk,
                  _Dot.pend,
                ],
              ),
              _GoalRow(
                title: 'Theology reading 1hr / day',
                status: '35m today',
                statusColor: AppColors.goalAtRisk,
                dots: const [
                  _Dot.ok,
                  _Dot.ok,
                  _Dot.ok,
                  _Dot.miss,
                  _Dot.ok,
                  _Dot.todayProg,
                  _Dot.pend,
                ],
                subline: 'Today: 35m of 60m — still in progress',
                progress: 0.58,
                progressColor: AppColors.dotTodayProg,
              ),
              const SizedBox(height: 14),
              _SectionLabel(text: 'Weekly goals'),
              _GymWeekRow(
                title: 'Gym 3x / week',
                status: '2 of 3',
                statusColor: AppColors.goalOnTrack,
              ),
              _GoalRow(
                title: 'Language learning 3hrs / week',
                status: '2h 15m',
                statusColor: AppColors.goalOnTrack,
                dots: const [],
                showDots: false,
                subline: '2h 15m of 3h — 45m remaining, 2 days left',
                progress: 0.75,
                progressColor: AppColors.dotOk,
                progressBeforeSubline: true,
              ),
              _GoalRow(
                title: 'Dancing 3hrs / week',
                status: '45m',
                statusColor: AppColors.goalAtRisk,
                dots: const [],
                showDots: false,
                subline: '45m of 3h — 2h 15m remaining, 2 days left',
                progress: 0.25,
                progressColor: AppColors.dotTodayProg,
                lastBorder: false,
                progressBeforeSubline: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.slate600,
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.leading,
    required this.leadingColor,
    required this.rest,
  });

  final String leading;
  final Color leadingColor;
  final String rest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: AppColors.slate600),
          children: [
            TextSpan(
              text: leading,
              style: TextStyle(fontWeight: FontWeight.w500, color: leadingColor),
            ),
            TextSpan(text: ' $rest'),
          ],
        ),
      ),
    );
  }
}

enum _Dot { ok, miss, pend, todayOk, todayMiss, todayProg }

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.title,
    required this.status,
    required this.statusColor,
    required this.dots,
    this.showDots = true,
    this.subline,
    this.progress,
    this.progressColor,
    this.lastBorder = true,
    this.progressBeforeSubline = false,
  });

  final String title;
  final String status;
  final Color statusColor;
  final List<_Dot> dots;
  final bool showDots;
  final String? subline;
  final double? progress;
  final Color? progressColor;
  final bool lastBorder;
  /// When true (weekly goals), progress bar appears above the subline.
  final bool progressBeforeSubline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: lastBorder
            ? const Border(bottom: BorderSide(color: AppColors.slate200, width: 0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ],
          ),
          if (showDots && dots.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: List.generate(7, (i) {
                return Padding(
                  padding: EdgeInsets.only(right: i < 6 ? 4 : 0),
                  child: _GoalDot(kind: dots[i]),
                );
              }),
            ),
            const SizedBox(height: 2),
            Row(
              children: List.generate(7, (i) {
                const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                return Padding(
                  padding: EdgeInsets.only(right: i < 6 ? 4 : 0),
                  child: SizedBox(
                    width: 12,
                    child: Text(
                      letters[i],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9,
                        height: 1,
                        color: AppColors.slate400,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
          if (progress != null && progressColor != null && progressBeforeSubline) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.slate200,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor!),
              ),
            ),
          ],
          if (subline != null) ...[
            const SizedBox(height: 6),
            Text(
              subline!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.slate500,
              ),
            ),
          ],
          if (progress != null && progressColor != null && !progressBeforeSubline) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.slate200,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalDot extends StatelessWidget {
  const _GoalDot({required this.kind});

  final _Dot kind;

  @override
  Widget build(BuildContext context) {
    const size = 12.0;
    switch (kind) {
      case _Dot.ok:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.dotOk,
            shape: BoxShape.circle,
          ),
        );
      case _Dot.miss:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.dotMiss,
            shape: BoxShape.circle,
          ),
        );
      case _Dot.pend:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.slate200, width: 1.5),
          ),
        );
      case _Dot.todayOk:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.dotOk,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.slate900, width: 2),
          ),
        );
      case _Dot.todayMiss:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.dotMiss,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.slate900, width: 2),
          ),
        );
      case _Dot.todayProg:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.dotTodayProg,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.slate900, width: 2),
          ),
        );
    }
  }
}

class _GymWeekRow extends StatelessWidget {
  const _GymWeekRow({
    required this.title,
    required this.status,
    required this.statusColor,
  });

  final String title;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.slate200, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GymCheck(),
                  const SizedBox(width: 4),
                  _GymCheck(),
                  const SizedBox(width: 4),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.slate200, width: 1.5),
                    ),
                  ),
                ],
              ),
              const Text(
                '2 days left in week',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.slate500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GymCheck extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        color: AppColors.calGreen,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        SolarLinearIcons.checkRead,
        size: 10,
        color: Colors.white,
      ),
    );
  }
}
