import 'dart:async';
import 'package:nx_cards/goals/streak_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/progress/progress_page.dart';
import 'package:nx_cards/scheduling/review_progression.dart';

String goalKey({String? language, int? bookId}) =>
    bookId == null ? 'language:$language' : 'book:$bookId';

Map<DateTime, int> dailyRecallCounts(List<StudyCard> cards, DateTime now) {
  final counts = <DateTime, int>{};
  for (final card in cards) {
    final seen = <(StudyCue, String)>{};
    for (final cue in card.directions) {
      for (final review in card.reviewHistoryFor(cue)) {
        if (review.reviewedAt.isAfter(now) || !seen.add((cue, review.id))) {
          continue;
        }
        final time = review.reviewedAt.toLocal();
        final day = DateTime(time.year, time.month, time.day);
        counts.update(day, (n) => n + 1, ifAbsent: () => 1);
      }
    }
  }
  return counts;
}

int recallsToday(List<StudyCard> cards, DateTime now) {
  final local = now.toLocal();
  return dailyRecallCounts(cards, now)[DateTime(
        local.year,
        local.month,
        local.day,
      )] ??
      0;
}

/// An ongoing streak must reach yesterday. Today extends it only after the
/// goal is met. Calendar dates (rather than 24-hour subtraction) handle DST.
int dailyGoalStreak(Map<DateTime, int> counts, int goal, DateTime now) {
  if (goal <= 0) return 0;
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  var day = DateTime(today.year, today.month, today.day - 1);
  var streak = 0;
  while ((counts[day] ?? 0) >= goal) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  if (streak > 0 && (counts[today] ?? 0) >= goal) streak++;
  return streak;
}

// Recompute on return from study, new synced histories, and a local day change.
final goalClockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

class DailyGoalBar extends ConsumerWidget {
  const DailyGoalBar({super.key, required this.name, this.bookId});
  final String name;
  final int? bookId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = (language: bookId == null ? name : null, bookId: bookId);
    final cards = ref.watch(sourceProgressCardsProvider(source));
    final settings = ref.watch(reviewProgressionSettingsProvider);
    final goal =
        settings.asData?.value.dailyGoals[goalKey(
          language: name,
          bookId: bookId,
        )] ??
        0;
    final now = ref.watch(goalClockProvider).asData?.value ?? DateTime.now();
    final counts = cards.asData == null
        ? null
        : dailyRecallCounts(cards.asData!.value, now);
    final count = counts == null
        ? null
        : counts[DateTime(now.year, now.month, now.day)] ?? 0;
    final streak = counts == null ? 0 : dailyGoalStreak(counts, goal, now);
    final theme = Theme.of(context);
    final subtitle = cards.hasError
        ? 'Recall count unavailable · View progress'
        : count == null
        ? 'Loading today’s recalls…'
        : goal == 0
        ? '$count recalls today · Set a goal in Settings'
        : count >= goal
        ? 'Goal reached · View progress'
        : '${goal - count} to go · View progress';
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        key: const ValueKey('daily-goal-bar'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProgressPage(language: name, bookId: bookId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('Daily goal', style: theme.textTheme.titleSmall),
                  if (streak > 0) StreakBadge(days: streak),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                settings.isLoading
                    ? 'Loading goal…'
                    : goal == 0
                    ? 'No goal set'
                    : '${count ?? '—'} / $goal recalls',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: count == null
                    ? null
                    : goal == 0
                    ? 0
                    : (count / goal).clamp(0, 1),
                color: streakAccent,
                backgroundColor: streakAccent.withValues(alpha: .15),
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DailyGoalSettings extends ConsumerStatefulWidget {
  const DailyGoalSettings({super.key});
  @override
  ConsumerState<DailyGoalSettings> createState() => _DailyGoalSettingsState();
}

class _DailyGoalSettingsState extends ConsumerState<DailyGoalSettings> {
  bool saving = false;
  Future<void> edit(String key, String name, int current) async {
    final input = TextEditingController(text: '$current');
    String? error;
    final value = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('$name daily goal'),
          content: TextField(
            controller: input,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Recalls per day',
              helperText: '0 turns the goal off',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final n = int.tryParse(input.text.trim());
                if (n == null || n < 0 || n > 100000) {
                  update(() => error = 'Enter 0 to 100000.');
                  return;
                }
                Navigator.pop(context, n);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    // The dialog may still be animating out when its future completes.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
    if (value == null || !mounted) return;
    setState(() => saving = true);
    try {
      await ref
          .read(reviewProgressionSettingsStoreProvider)
          .saveGoal(key, value);
      ref.invalidate(reviewProgressionSettingsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save goal: $e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(cardsSourcesProvider);
    final goals =
        ref.watch(reviewProgressionSettingsProvider).asData?.value.dailyGoals ??
        const <String, int>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Daily recall goals',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 7),
        const Text(
          'Add a daily goal for each language or book. Every recall attempt counts. Goals default to 0 (off).',
        ),
        const SizedBox(height: 12),
        sources.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(cardsSourcesProvider),
            child: const Text('Retry loading languages and books'),
          ),
          data: (items) => Column(
            children: [
              if (items.isEmpty)
                const Text('Your languages and books will appear here.'),
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle: Text(
                    '${item.kind == 'book' ? 'Book' : 'Language'} · ${goals['${item.kind}:${item.id}'] ?? 0} recalls/day',
                  ),
                  trailing: TextButton(
                    onPressed: saving
                        ? null
                        : () => edit(
                            '${item.kind}:${item.id}',
                            item.name,
                            goals['${item.kind}:${item.id}'] ?? 0,
                          ),
                    child: Text(
                      (goals['${item.kind}:${item.id}'] ?? 0) == 0
                          ? 'Add goal'
                          : 'Edit',
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (saving) const LinearProgressIndicator(),
      ],
    );
  }
}
