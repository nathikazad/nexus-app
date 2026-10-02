import 'package:nx_cards/study/recall_priority.dart';
import 'package:nx_cards/scheduling/study_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/study/language/language_audio_controls.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/card_details_page.dart';

enum RecallRecapAction { repeatIncorrect }

/// Retry only misses and untried prompts, retaining their latest saved state.
List<StudyPrompt> retryRecallPrompts(
  List<StudyPrompt> prompts,
  Map<int, CardRating> ratings,
  Map<int, StudyCard> latestCards,
) {
  final indices = [
    for (var i = 0; i < prompts.length; i++)
      if (ratings[i] == null || ratings[i] == CardRating.again) i,
  ];
  final original = List<int>.of(indices);
  indices.shuffle();
  // A shuffle can randomly preserve the entire order. Avoid that when possible.
  if (indices.length > 1 &&
      List.generate(
        indices.length,
        (i) => indices[i] == original[i],
      ).every((v) => v)) {
    indices.add(indices.removeAt(0));
  }
  return spaceRepeatedRecallCards([
    for (final i in indices)
      prompts[i].withCard(latestCards[prompts[i].cardId] ?? prompts[i].card),
  ]);
}

class RecallRecapEntry {
  const RecallRecapEntry({required this.card, required this.rating});

  final StudyCard card;
  final CardRating? rating;
}

class RecallRecapPage extends ConsumerStatefulWidget {
  const RecallRecapPage({
    this.studyScope,
    super.key,
    required this.reviewedCount,
    required this.totalCount,
    required this.missCount,
    required this.entries,
    this.onRepeatIncorrect,
    this.wordRecap,
    this.wordRecapTitle = 'WORDS',
  });

  final StudyScope? studyScope;
  final int reviewedCount;
  final int totalCount;
  final int missCount;
  final List<RecallRecapEntry> entries;
  final VoidCallback? onRepeatIncorrect;
  final Widget? wordRecap;
  final String wordRecapTitle;

  @override
  ConsumerState<RecallRecapPage> createState() => _RecallRecapPageState();
}

class _RecallRecapPageState extends ConsumerState<RecallRecapPage> {
  Widget _actions() => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Return'),
        ),
      ),
      if (widget.missCount > 0 || widget.reviewedCount < widget.totalCount) ...[
        const SizedBox(width: 12),
        Expanded(
          child: Tooltip(
            message: 'Retry missed and untried cards',
            child: FilledButton(
              onPressed: widget.onRepeatIncorrect,
              child: const Text('Repeat'),
            ),
          ),
        ),
      ],
    ],
  );

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
                    color: RecallColors.sky,
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
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 20,
                            children: [
                              Expanded(
                                child: _RecapStat(
                                  value:
                                      '${widget.reviewedCount - widget.missCount}',
                                  label: 'Recalled',
                                  color: RecallColors.emerald,
                                ),
                              ),
                              Expanded(
                                child: _RecapStat(
                                  value: '${widget.missCount}',
                                  label: 'Not recalled',
                                  color: RecallColors.rose,
                                ),
                              ),
                              Expanded(
                                child: _RecapStat(
                                  value:
                                      '${widget.totalCount - widget.reviewedCount}',
                                  label: 'Not tried',
                                  color: RecallColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _actions(),
                  const SizedBox(height: 24),
                  Text(widget.wordRecapTitle, style: monoLabel),
                  const SizedBox(height: 9),
                  widget.wordRecap ?? _RecallWordRecap(entries: widget.entries),
                  const SizedBox(height: 24),
                  _actions(),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RecallWordRecap extends StatelessWidget {
  const _RecallWordRecap({required this.entries});

  final List<RecallRecapEntry> entries;

  @override
  Widget build(BuildContext context) {
    final palette = RecallPalette.of(context);
    return DecoratedBox(
      key: const ValueKey('recall-word-recap'),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.line),
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
}

class _RecallWordRecapRow extends ConsumerWidget {
  const _RecallWordRecapRow({required this.entry});

  final RecallRecapEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (label, color) = switch (entry.rating) {
      CardRating.again => ('INCORRECT', RecallColors.rose),
      CardRating.good ||
      CardRating.easy ||
      CardRating.hard => ('CORRECT', RecallColors.emerald),
      null => ('NOT REVIEWED', RecallColors.muted),
    };
    final content = entry.card.content;
    final audioUrl = content is LanguageCardContent ? content.audioUrl : null;
    final audio = audioUrl?.isNotEmpty == true
        ? ref.watch(cardAudioRepositoryProvider)
        : null;
    final transliteration = content is LanguageCardContent
        ? content.transliteration
        : '';
    return InkWell(
      key: ValueKey('recap-open-card-${entry.card.id}'),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => CardDetailsPage(card: entry.card)),
      ),
      child: Padding(
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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
                if (audio != null && audioUrl != null) ...[
                  const SizedBox(height: 6),
                  PronunciationButton(
                    key: ValueKey('recap-audio-${entry.card.id}-$audioUrl'),
                    audioUrl: audioUrl,
                    repository: audio,
                  ),
                ],
              ],
            ),
          ],
        ),
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
      SizedBox(
        height: 48,
        child: Center(
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: RecallColors.muted, fontSize: 12),
      ),
    ],
  );
}
