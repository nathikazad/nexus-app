import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/review_progression_service.dart';

class RecallRecapEntry {
  const RecallRecapEntry({required this.card, required this.rating});

  final StudyCard card;
  final CardRating? rating;
}

class RecallRecapPage extends ConsumerStatefulWidget {
  const RecallRecapPage({
    super.key,
    required this.reviewedCount,
    required this.totalCount,
    required this.missCount,
    required this.entries,
  });

  final int reviewedCount;
  final int totalCount;
  final int missCount;
  final List<RecallRecapEntry> entries;

  @override
  ConsumerState<RecallRecapPage> createState() => _RecallRecapPageState();
}

class _RecallRecapPageState extends ConsumerState<RecallRecapPage> {
  ReviewProgressionPlan? _progression;
  Object? _progressionError;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_applyProgression);
  }

  Future<void> _applyProgression() async {
    try {
      final result = await ref.read(reviewProgressionRunnerProvider)(
        widget.entries
            .where((entry) => entry.rating != null)
            .map((entry) => entry.card),
      );
      if (mounted) setState(() => _progression = result);
    } catch (error) {
      if (mounted) setState(() => _progressionError = error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    size: 48,
                    color: RecallColors.violet,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Session complete',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.reviewedCount} of ${widget.totalCount} cards reviewed',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: RecallColors.muted),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 24,
                    runSpacing: 8,
                    children: [
                      _RecapStat(
                        value: '${widget.reviewedCount - widget.missCount}',
                        label: 'Recalled',
                        color: RecallColors.emerald,
                      ),
                      _RecapStat(
                        value: '${widget.missCount}',
                        label: 'Not recalled',
                        color: RecallColors.rose,
                      ),
                    ],
                  ),
                  if (_progression case final progression?
                      when progression.changed) ...[
                    const SizedBox(height: 17),
                    Text(
                      _progressionSummary(progression),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: RecallColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ] else if (_progressionError != null) ...[
                    const SizedBox(height: 17),
                    const Text(
                      'Learning lists could not be updated.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: RecallColors.rose, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text('WORDS', style: monoLabel),
                  const SizedBox(height: 9),
                  _RecallWordRecap(entries: widget.entries),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Return to categories'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  String _progressionSummary(ReviewProgressionPlan progression) {
    final parts = <String>[];
    if (progression.movedToPast > 0) {
      parts.add('${progression.movedToPast} moved to Past');
    }
    if (progression.movedToCurrent > 0) {
      parts.add('${progression.movedToCurrent} moved to Current');
    }
    if (progression.replacements > 0) {
      parts.add('${progression.replacements} Future added to Current');
    }
    return parts.join(' · ');
  }
}

class _RecallWordRecap extends StatelessWidget {
  const _RecallWordRecap({required this.entries});

  final List<RecallRecapEntry> entries;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: RecallColors.line),
    ),
    child: Column(
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          if (index > 0) const Divider(height: 1),
          _RecallWordRecapRow(entry: entries[index]),
        ],
      ],
    ),
  );
}

class _RecallWordRecapRow extends StatelessWidget {
  const _RecallWordRecapRow({required this.entry});

  final RecallRecapEntry entry;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (entry.rating) {
      CardRating.again => ('INCORRECT', RecallColors.rose),
      CardRating.good ||
      CardRating.easy ||
      CardRating.hard => ('CORRECT', RecallColors.emerald),
      null => ('NOT REVIEWED', RecallColors.muted),
    };
    final content = entry.card.content;
    final transliteration = content is LanguageCardContent
        ? content.transliteration
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.card.front,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(entry.card.back, style: const TextStyle(fontSize: 15)),
                if (transliteration.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    transliteration,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: RecallColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'monospace',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapStat extends StatelessWidget {
  const _RecapStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(label, style: const TextStyle(color: RecallColors.muted)),
    ],
  );
}
