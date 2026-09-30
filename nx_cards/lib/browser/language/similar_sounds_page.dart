import 'package:nx_cards/browser/card_list/scroll_position_indicator.dart';
import 'package:nx_cards/app/adaptive_card_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/browser_error.dart';
import 'package:nx_cards/study/language/language_audio_controls.dart';
import 'package:nx_cards/study/language/similar_sounds.dart';

class SimilarSoundsPage extends ConsumerWidget {
  const SimilarSoundsPage({super.key, required this.language});
  final String language;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      cardsCollectionProvider((language: language, bookId: null)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Similar words')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => BrowserLoadError(
          error: e,
          onRetry: () => ref.read(cardsInvalidationProvider)(),
        ),
        data: (dashboard) {
          final groups = manualSimilarSoundGroups(dashboard.cards);
          if (groups.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No manual groups assigned to your Current words yet.',
                ),
              ),
            );
          }
          return ScrollPositionIndicator(
            builder: (controller) => ListView.builder(
              key: const PageStorageKey('manual-similar-words'),
              controller: controller,
              primary: false,
              padding: const EdgeInsets.all(12),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return Card(
                  child: ExpansionTile(
                    key: PageStorageKey('manual-${group.label}'),
                    title: Text(
                      group.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${group.cards.length} words'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        child: SimilarSoundGrid(cards: group.cards),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class SimilarSoundGrid extends StatelessWidget {
  const SimilarSoundGrid({super.key, required this.cards, this.testedIds});
  final List<StudyCard> cards;
  final Set<int>? testedIds;

  @override
  Widget build(BuildContext context) => AdaptiveCardGrid(
    minimumCardWidth: 220,
    maxColumns: cards.length.clamp(1, 4),
    spacing: 12,
    children: [
      for (final card in cards)
        SimilarSoundWord(
          key: ValueKey('similar-word-${card.id}'),
          card: card,
          notAsked: testedIds != null && !testedIds!.contains(card.id),
        ),
    ],
  );
}

class SimilarSoundWord extends ConsumerWidget {
  const SimilarSoundWord({
    super.key,
    required this.card,
    this.notAsked = false,
  });
  final StudyCard card;
  final bool notAsked;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = card.content as LanguageCardContent;
    final audio = ref.watch(cardAudioRepositoryProvider);
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    content.originalScript,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                if (audio != null && content.audioUrl?.isNotEmpty == true)
                  PronunciationButton(
                    key: ValueKey('compare-audio-${card.id}'),
                    audioUrl: content.audioUrl!,
                    repository: audio,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              content.transliteration,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(content.english),
            if (notAsked) ...[
              const SizedBox(height: 12),
              Text(
                'Not asked',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
