import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/card_details_page.dart';
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
          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Sound'),
                    Tab(text: 'Written'),
                    Tab(text: 'Other'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final kind in SimilarGroupKind.values)
                        ScrollPositionIndicator(
                          key: ValueKey(kind),
                          builder: (controller) {
                            final selected = sortedSimilarGroups(
                              groups.where((g) => g.kind == kind),
                            );
                            return ListView.builder(
                              key: PageStorageKey('similar-${kind.name}'),
                              controller: controller,
                              primary: false,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                20,
                                16,
                                24,
                              ),
                              itemCount: selected.isEmpty ? 1 : selected.length,
                              itemBuilder: (context, index) => selected.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text('No groups yet.'),
                                    )
                                  : SimilarWordGroupPanel(
                                      group: selected[index],
                                    ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SimilarWordGroups extends StatelessWidget {
  const SimilarWordGroups({super.key, required this.groups});
  final List<SimilarSoundGroup> groups;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [for (final group in groups) SimilarWordGroupPanel(group: group)],
  );
}

class SimilarWordGroupPanel extends StatelessWidget {
  const SimilarWordGroupPanel({super.key, required this.group});
  final SimilarSoundGroup group;
  @override
  Widget build(BuildContext context) {
    final palette = RecallPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 12),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    group.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SimilarRetentionPill(fraction: similarGroupRetention(group)),
                const SizedBox(width: 16),
                Expanded(child: Divider(color: palette.line, height: 1)),
              ],
            ),
          ),
          SimilarSoundGrid(cards: group.cards, retentionKind: group.kind),
        ],
      ),
    );
  }
}

class SimilarSoundGrid extends StatelessWidget {
  const SimilarSoundGrid({
    super.key,
    required this.cards,
    this.testedIds,
    this.retentionKind,
    this.ratings,
  });
  final List<StudyCard> cards;
  final Set<int>? testedIds;
  final SimilarGroupKind? retentionKind;
  final Map<int, CardRating?>? ratings;

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
          resultLabel: ratings == null
              ? null
              : switch (ratings![card.id]) {
                  CardRating.again => 'Not recalled',
                  null => 'Not tried',
                  _ => 'Recalled',
                },
          retention: retentionKind == null
              ? null
              : similarWordRetention(card, retentionKind!),
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
    this.retention,
    this.resultLabel,
  });
  final StudyCard card;
  final bool notAsked;
  final double? retention;
  final String? resultLabel;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = card.content as LanguageCardContent;
    final audio = ref.watch(cardAudioRepositoryProvider);
    final colors = Theme.of(context).colorScheme;
    final palette = RecallPalette.of(context);
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: palette.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => CardDetailsPage(card: card),
                        ),
                      ),
                      child: Text(
                        content.originalScript,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: palette.ink,
                        ),
                      ),
                    ),
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
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(
                  child: Text(
                    content.transliteration,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: palette.muted,
                    ),
                  ),
                ),
                if (retention != null) ...[
                  const SizedBox(width: 8),
                  SimilarRetentionPill(fraction: retention!),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              content.english,
              style: TextStyle(fontSize: 12, height: 1.4, color: palette.ink),
            ),
            if (resultLabel != null) ...[
              const SizedBox(height: 8),
              Text(resultLabel!),
            ],
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

class SimilarRetentionPill extends StatelessWidget {
  const SimilarRetentionPill({super.key, required this.fraction});
  final double fraction;
  @override
  Widget build(BuildContext context) {
    final strong = fraction >= .8;
    return Tooltip(
      message: 'Retention',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: strong ? const Color(0xffecfdf5) : const Color(0xfffff7ed),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          '${(fraction * 100).round()}%',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: .55,
            color: strong ? RecallColors.emerald : RecallColors.orange,
          ),
        ),
      ),
    );
  }
}
