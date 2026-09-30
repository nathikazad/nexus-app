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
      appBar: AppBar(title: const Text('Similar sounding words')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => BrowserLoadError(
          error: e,
          onRetry: () => ref.read(cardsInvalidationProvider)(),
        ),
        data: (dashboard) {
          final groups = similarSoundGroups(dashboard.cards);
          if (groups.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No similar sounds among your Current Chinese words yet.',
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: groups.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Current words · A word may appear in more than one group.',
                  ),
                );
              }
              final group = groups[index - 1];
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Card(
                    child: ExpansionTile(
                      key: PageStorageKey(
                        'sounds-${group.kind.name}-${group.label}',
                      ),
                      title: Text(
                        group.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${group.kind.label} · ${group.cards.length} words',
                      ),
                      children: [
                        for (final card in group.cards)
                          SimilarSoundWord(card: card),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SimilarSoundWord extends ConsumerWidget {
  const SimilarSoundWord({super.key, required this.card});
  final StudyCard card;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = card.content as LanguageCardContent;
    final audio = ref.watch(cardAudioRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.originalScript,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(height: 6),
                Text(
                  content.transliteration,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(content.english),
              ],
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
    );
  }
}
