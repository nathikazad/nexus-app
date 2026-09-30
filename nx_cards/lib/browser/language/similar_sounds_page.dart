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

const _tabKinds = [
  SimilarSoundKind.manual,
  SimilarSoundKind.syllable,
  SimilarSoundKind.beginning,
  SimilarSoundKind.ending,
  SimilarSoundKind.nearby,
];

class SimilarSoundsPage extends ConsumerWidget {
  const SimilarSoundsPage({super.key, required this.language});
  final String language;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      cardsCollectionProvider((language: language, bookId: null)),
    );
    return DefaultTabController(
      length: _tabKinds.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Similar sounding words'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final kind in _tabKinds) Tab(text: kind.label)],
          ),
        ),
        body: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => BrowserLoadError(
            error: e,
            onRetry: () => ref.read(cardsInvalidationProvider)(),
          ),
          data: (dashboard) {
            final groups =
                similarSoundGroups(dashboard.cards, includeEveryCategory: true)
                  ..sort((a, b) {
                    final bySize = b.cards.length.compareTo(a.cards.length);
                    if (bySize != 0) return bySize;
                    return a.label.compareTo(b.label);
                  });
            groups.addAll(manualSimilarSoundGroups(dashboard.cards));
            return TabBarView(
              children: [
                for (final kind in _tabKinds)
                  _SimilarSoundsTab(
                    key: ValueKey(kind),
                    kind: kind,
                    groups: groups.where((g) => g.kind == kind).toList(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SimilarSoundsTab extends StatelessWidget {
  const _SimilarSoundsTab({
    super.key,
    required this.kind,
    required this.groups,
  });
  final SimilarSoundKind kind;
  final List<SimilarSoundGroup> groups;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            kind == SimilarSoundKind.manual
                ? 'No manual groups assigned to your Current words yet.'
                : 'No matching Current words in this category yet.',
          ),
        ),
      );
    }
    return ScrollPositionIndicator(
      builder: (controller) => ListView.builder(
        key: PageStorageKey('similar-sounds-${kind.name}'),
        controller: controller,
        primary: false,
        padding: const EdgeInsets.all(12),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return Card(
            child: ExpansionTile(
              key: PageStorageKey('sounds-${group.kind.name}-${group.label}'),
              title: Text(
                group.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${group.kind.label} · ${group.cards.length} words',
              ),
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
