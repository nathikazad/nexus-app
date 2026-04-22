import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/features/goals/goal_detail/goal_detail_variant.dart';

/// Static reference UI for goal detail (`reference/partials/page-goal-detail-*.html`).
///
/// One [MaterialPageRoute] switches on [variant]; later this can read a goal id / API.
class GoalDetailPage extends StatelessWidget {
  const GoalDetailPage({super.key, required this.variant});

  final GoalDetailVariant variant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailAppBar(onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: switch (variant) {
                  GoalDetailVariant.wake => _WakeBody(),
                  GoalDetailVariant.sleep => const _SleepBody(),
                  GoalDetailVariant.gym => const _GymBody(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailAppBar extends StatelessWidget {
  const _DetailAppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(SolarLinearIcons.arrowLeft, size: 22, color: AppColors.slate600),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const Expanded(
            child: Text(
              'GOAL',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: AppColors.slate900,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz, size: 22, color: AppColors.slate500),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }
}

// --- Section chrome (reference: text-[10px] uppercase tracking-widest) ---
class _Kicker extends StatelessWidget {
  const _Kicker(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.slate500,
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({
    required this.count,
    required this.unit,
    this.muted = false,
  });

  final int count;
  final String unit;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final fg = muted ? AppColors.slate500 : AppColors.accent;
    final bg = muted
        ? AppColors.slate100
        : AppColors.accentLight.withValues(alpha: 0.5);
    final numColor = muted ? AppColors.slate700 : AppColors.slate900;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(SolarBoldIcons.fire, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: numColor,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            unit,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Wake (time threshold) — see page-goal-detail-wake.html
// =============================================================================
class _WakeBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Wake up before 7 AM',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: AppColors.slate900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Every day · end of sleep before 07:00',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.slate500,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: const [
                    Text(
                      '6:48',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate900,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'AM',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 12, color: AppColors.slate500),
                    children: [
                      TextSpan(text: 'today · '),
                      TextSpan(
                        text: '12 min before goal',
                        style: TextStyle(
                          color: AppColors.goalOnTrack,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const _StreakPill(count: 3, unit: 'days'),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 32,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              const thresholdX = 0.75;
              const dotX = 0.73;
              return Stack(
                children: [
                  Center(child: Container(height: 1, color: AppColors.slate200)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: w * thresholdX,
                      height: 1,
                      child: const ColoredBox(color: AppColors.dotOk),
                    ),
                  ),
                  Positioned(
                    left: w * thresholdX,
                    top: 0,
                    bottom: 0,
                    child: const VerticalDivider(width: 1, color: AppColors.slate700, thickness: 1),
                  ),
                  Positioned(
                    left: w * thresholdX - 12,
                    top: -2,
                    child: const Text('7 AM', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: AppColors.slate700)),
                  ),
                  Positioned(
                    left: w * dotX - 6,
                    top: 10,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.dotOk,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [BoxShadow(color: Color(0x330F172A), blurRadius: 0.5)],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('5 AM', style: TextStyle(fontSize: 9, color: AppColors.slate400)),
            Text('8 AM', style: TextStyle(fontSize: 9, color: AppColors.slate400)),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _Kicker('THIS WEEK'),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                children: [
                  const TextSpan(text: ''),
                  const TextSpan(text: '5', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate700)),
                  const TextSpan(text: ' of 7 hit'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _wakeSwimRow('M', 0.67, '6:32', false, false, false),
        _wakeSwimRow('T', 0.73, '6:55', false, false, false),
        _wakeSwimRow('W', 0.88, '7:38', true, false, false),
        _wakeSwimRow('T', 0.70, '6:40', false, false, false),
        _wakeSwimRow('F', 0.72, '6:50', false, false, false),
        _wakeSwimRow('S', 0.71, '6:48', false, true, false),
        _wakeSwimRow('S', 0, '—', false, false, true),
        const SizedBox(height: 8),
        const Row(
          children: [
            Text('5 AM', style: TextStyle(fontSize: 10, color: AppColors.slate400)),
            Expanded(child: Divider(height: 1, color: AppColors.slate100)),
            Text('8 AM', style: TextStyle(fontSize: 10, color: AppColors.slate400)),
          ],
        ),
        const SizedBox(height: 28),
        _trend8Week(),
        const SizedBox(height: 24),
        const _HowMeasuredPanel(
          rows: [
            ('Tracks', 'Sleep actions'),
            ('Hits when', 'wake time ≤ 07:00'),
            ('Day attribution', 'wake time'),
            ('Cadence', 'daily'),
          ],
        ),
        const SizedBox(height: 20),
        const _BottomActions(
          deleteBlurb: 'Sleep history stays; this goal stops tracking',
        ),
      ],
    );
  }

  static Widget _trend8Week() {
    const h = <double>[0.43, 0.57, 0.71, 0.57, 0.71, 0.86, 0.71, 0.71];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _Kicker('8-WEEK TREND'),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                children: const [
                  TextSpan(text: 'this wk '),
                  TextSpan(text: '5 / 7', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate700)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(8, (i) {
              final accent = i == 7;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    height: 80 * h[i],
                    decoration: BoxDecoration(
                      color: accent ? AppColors.accent : AppColors.slate200,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('8w ago', style: TextStyle(fontSize: 10, color: AppColors.slate400)),
            Text('this wk', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.accent)),
          ],
        ),
      ],
    );
  }
}

Widget _wakeSwimRow(
  String letter,
  double pos,
  String time,
  bool miss,
  bool today,
  bool pending,
) {
  final dotColor = pending
      ? Colors.transparent
      : (miss ? AppColors.dotMiss : AppColors.dotOk);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 10,
              fontWeight: today ? FontWeight.w600 : FontWeight.w500,
              color: today ? AppColors.accent : (pending ? AppColors.slate300 : AppColors.slate400),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              border: Border.all(color: today ? AppColors.accent : Colors.transparent, width: 1),
              borderRadius: BorderRadius.circular(4),
              color: today ? AppColors.accentLight.withValues(alpha: 0.3) : null,
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final trackW = c.maxWidth;
                return Stack(
                  children: [
                    Center(
                      child: Container(height: 1, color: AppColors.slate100),
                    ),
                    if (!pending)
                      Positioned(
                        left: trackW * pos - 5,
                        top: 1,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            border: today ? Border.all(color: AppColors.slate900, width: 2) : null,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            time,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10,
              fontWeight: today ? FontWeight.w600 : FontWeight.w500,
              color: pending
                  ? AppColors.slate300
                  : (miss ? AppColors.goalMissed : AppColors.slate700),
            ),
          ),
        ),
      ],
    ),
  );
}

// =============================================================================
// Sleep (duration) — see page-goal-detail-sleep.html
// =============================================================================
class _SleepBody extends StatelessWidget {
  const _SleepBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Sleep 8 hours',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.slate900, height: 1.2),
        ),
        const SizedBox(height: 4),
        const Text(
          'Every day · ≥ 8h · attributed to wake time',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate500),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('6h 50m', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: AppColors.slate900)),
                SizedBox(height: 2),
                Text('today, so far', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
              ],
            ),
            const _StreakPill(count: 0, unit: 'days', muted: true),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: const LinearProgressIndicator(
            value: 0.85,
            minHeight: 6,
            backgroundColor: AppColors.slate100,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.goalAtRisk),
          ),
        ),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0h', style: TextStyle(fontSize: 10, color: AppColors.slate400)),
            Text('4h', style: TextStyle(fontSize: 10, color: AppColors.slate400)),
            Text('8h target', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.slate600)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _Kicker('THIS WEEK'),
            Text.rich(
              TextSpan(
                text: '3',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate700),
                children: const [
                  TextSpan(text: ' of 7 hit', style: TextStyle(fontWeight: FontWeight.normal, color: AppColors.slate500)),
                ],
              ),
              style: const TextStyle(fontSize: 11, color: AppColors.slate500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _sleepWeekGrid(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.slate50,
            border: Border.all(color: AppColors.slate100),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Saturday — in progress', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate900)),
                  Text('6h 50m / 8h', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(SolarLinearIcons.moonStars, size: 20, color: AppColors.slate500),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sleep · main\n12:08 AM → 6:58 AM (still recording)',
                      style: TextStyle(fontSize: 11, color: AppColors.slate500, height: 1.3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _Kicker('8-WEEK TREND'),
        const SizedBox(height: 8),
        _sleepTrendBars(),
        const SizedBox(height: 24),
        const _HowMeasuredPanel(
          rows: [
            ('Tracks', 'Sleep actions'),
            ('Hits when', 'total duration ≥ 8h'),
            ('Day attribution', 'wake time'),
            ('Cadence', 'daily'),
          ],
        ),
        const SizedBox(height: 20),
        const _BottomActions(deleteBlurb: 'History stays; this goal stops tracking'),
      ],
    );
  }
}

Widget _sleepTrendBars() {
  const h = <double>[0.57, 1, 0.86, 0.71, 1, 1, 0.86, 0.71];
  return SizedBox(
    height: 80,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(8, (i) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              height: 80 * h[i],
              decoration: BoxDecoration(
                color: i == 7 ? AppColors.accent : AppColors.slate200,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ),
        );
      }),
    ),
  );
}

Widget _sleepWeekGrid() {
  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  const vals = ['8h 10m', '8h', '6h 20m', '8h 20m', '6h 40m', '6h 50m', '—'];
  const states = [0, 0, 1, 0, 1, 2, 3];
  return Row(
    children: List.generate(7, (i) {
      final c = states[i];
      final ok = c == 0;
      final miss = c == 1;
      final today = c == 2;
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: today ? Border.all(color: AppColors.accent) : null,
            color: today ? AppColors.accentLight.withValues(alpha: 0.3) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: today ? FontWeight.w600 : FontWeight.w500,
                  color: today ? AppColors.accent : (i == 6 ? AppColors.slate300 : AppColors.slate400),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: c == 3 ? null : (miss ? AppColors.dotMiss : (ok ? AppColors.dotOk : AppColors.dotTodayProg)),
                  shape: BoxShape.circle,
                  border: c == 3
                      ? Border.all(color: AppColors.slate200)
                      : (today ? Border.all(color: AppColors.slate900, width: 2) : null),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                vals[i],
                style: TextStyle(
                  fontSize: 10,
                  color: c == 3 ? AppColors.slate300 : (miss ? AppColors.slate500 : AppColors.slate700),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }),
  );
}

// =============================================================================
// Gym (weekly + slots) — see page-goal-detail-gym.html
// =============================================================================
class _GymBody extends StatelessWidget {
  const _GymBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Gym 3× / week',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.slate900, height: 1.2),
        ),
        const SizedBox(height: 4),
        const Text(
          '≥ 3 sessions per week · usually Mon, Wed, Fri at 12:30 PM',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate500),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: const [
                Text('2', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: AppColors.slate900)),
                Text(' / 3', style: TextStyle(fontSize: 18, color: AppColors.slate400, fontWeight: FontWeight.w500)),
              ],
            ),
            const _StreakPill(count: 4, unit: 'weeks'),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'sessions this week · 2 days left',
          style: TextStyle(fontSize: 12, color: AppColors.slate500),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: const LinearProgressIndicator(
            value: 2 / 3,
            minHeight: 6,
            backgroundColor: AppColors.slate100,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.goalAtRisk),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _Kicker('PREFERRED SLOTS'),
            TextButton(
              onPressed: () {},
              child: const Text('edit', style: TextStyle(fontSize: 11, color: AppColors.slate400)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Expanded(child: _GymSlotCard(day: 'Mon', done: true, time: '12:34 PM', sub: '62 min')),
            SizedBox(width: 8),
            Expanded(child: _GymSlotCard(day: 'Wed', done: true, time: '12:42 PM', sub: '58 min')),
            SizedBox(width: 8),
            Expanded(child: _GymSlotCard(day: 'Fri', missed: true, time: '12:30 scheduled', sub: 'missed')),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 11, color: AppColors.slate500),
              children: [
                TextSpan(text: 'Auto-create tasks for these slots — ', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.slate700)),
                TextSpan(text: 'on', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _Kicker('THIS WEEK'),
            Text('2 sessions logged', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
          ],
        ),
        const SizedBox(height: 8),
        const _GymWeekStrip(),
        const SizedBox(height: 8),
        const Text(
          '● scheduled slot   ● completed   ● missed',
          style: TextStyle(fontSize: 10, color: AppColors.slate400),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _Kicker('12-WEEK TREND'),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '9 / 12', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate700)),
                  const TextSpan(text: ' weeks hit', style: TextStyle(color: AppColors.slate500)),
                ],
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _gym12Grid(),
        const SizedBox(height: 24),
        const _HowMeasuredPanel(
          rows: [
            ('Tracks', 'Workouts tagged "gym"'),
            ('Hits when', '≥ 3 sessions in a week'),
            ('Day attribution', 'start time'),
            ('Cadence', 'weekly'),
            ('Slot tasks', 'Mon, Wed, Fri 12:30 PM'),
          ],
        ),
        const SizedBox(height: 20),
        const _BottomActions(
          deleteBlurb: 'Workouts stay; this goal stops tracking',
          editSub: 'Change target, slots, or tag filter',
        ),
      ],
    );
  }
}

class _GymSlotCard extends StatelessWidget {
  const _GymSlotCard({
    required this.day,
    this.done = false,
    this.missed = false,
    required this.time,
    required this.sub,
  });

  final String day;
  final bool done;
  final bool missed;
  final String time;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: missed ? const Color(0xFFFFF1F2) : Colors.white,
        border: Border.all(
          color: missed ? const Color(0xFFFECACA) : AppColors.slate100,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(day, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate700)),
              if (done)
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(color: AppColors.dotOk, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Icon(SolarLinearIcons.checkRead, size: 8, color: Colors.white),
                )
              else if (missed)
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(fontSize: 10, color: missed ? AppColors.slate400 : AppColors.slate500),
          ),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10,
              fontWeight: missed ? FontWeight.w600 : FontWeight.w500,
              color: missed ? AppColors.dotMiss : AppColors.slate700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GymWeekStrip extends StatelessWidget {
  const _GymWeekStrip();

  @override
  Widget build(BuildContext context) {
    // 0 empty, 1 done, 2 miss, 3 today empty, 4 future
    const states = [1, 0, 1, 0, 2, 3, 4];
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: List.generate(7, (i) {
        final s = states[i];
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: s == 3 ? Border.all(color: AppColors.accent) : null,
              color: s == 3 ? AppColors.accentLight.withValues(alpha: 0.35) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 10,
                    color: s == 3
                        ? AppColors.accent
                        : (s == 4 ? AppColors.slate300 : AppColors.slate400),
                    fontWeight: s == 3 ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: s == 0
                        ? AppColors.slate100
                        : (s == 1
                            ? AppColors.dotOk
                            : (s == 2
                                ? AppColors.dotMiss
                                : (s == 3 ? null : null))),
                    shape: BoxShape.circle,
                    border: s == 3
                        ? Border.all(color: AppColors.slate300)
                        : (s == 0
                            ? null
                            : (s == 4
                                ? Border.all(color: AppColors.slate200)
                                : null)),
                  ),
                ),
                const SizedBox(height: 2),
                if (i == 0 || i == 2 || i == 4)
                  Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.slate400, shape: BoxShape.circle))
                else
                  const SizedBox(height: 4),
              ],
            ),
          ),
        );
      }),
    );
  }
}

Widget _gym12Grid() {
  const hit = <bool>[true, false, true, true, true, true, false, true, true, true, true, false];
  return SizedBox(
    height: 40,
    child: Row(
      children: List.generate(12, (i) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: hit[i] ? AppColors.dotOk : AppColors.slate100,
                  borderRadius: BorderRadius.circular(2),
                  border: i == 11 ? Border.all(color: AppColors.accent) : null,
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );
}

// =============================================================================
// Shared panels
// =============================================================================
class _HowMeasuredPanel extends StatelessWidget {
  const _HowMeasuredPanel({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.slate100),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.slate100),
      ),
      backgroundColor: AppColors.slate50.withValues(alpha: 0.6),
      collapsedBackgroundColor: AppColors.slate50.withValues(alpha: 0.6),
      title: const Row(
        children: [
          Icon(SolarLinearIcons.settings, size: 16, color: AppColors.slate400),
          SizedBox(width: 6),
          Text(
            'HOW THIS IS MEASURED',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: rows
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(e.$1, style: const TextStyle(fontSize: 13, color: AppColors.slate400)),
                        ),
                        Expanded(
                          child: Text(
                            e.$2,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate900),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.deleteBlurb, this.editSub = 'Change threshold time or filter'});

  final String deleteBlurb;
  final String editSub;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(color: AppColors.slate100, height: 1),
        const SizedBox(height: 8),
        _actionTile(
          icon: SolarLinearIcons.pen,
          title: 'Edit goal',
          subtitle: editSub,
        ),
        _actionTile(
          icon: SolarLinearIcons.pause,
          title: 'Pause',
          subtitle: 'Hide from the goals tab without deleting history',
        ),
        _actionTile(
          icon: SolarLinearIcons.trashBinMinimalistic,
          title: 'Delete goal',
          subtitle: deleteBlurb,
          danger: true,
        ),
      ],
    );
  }

  static Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    bool danger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: danger ? const Color(0xFFFFF1F2) : AppColors.slate100,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: danger ? AppColors.dotMiss : AppColors.slate600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: danger ? AppColors.dotMiss : AppColors.slate900,
                  ),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
