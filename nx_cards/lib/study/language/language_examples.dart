import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/card_details_page.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/language/language_audio_controls.dart';

class LanguageExamples extends StatelessWidget {
  const LanguageExamples({
    super.key,
    required this.examples,
    required this.audioRepository,
    required this.audioKeyPrefix,
    this.showHeading = true,
  });

  final List<LanguageExample> examples;
  final CardAudioRepository? audioRepository;
  final String audioKeyPrefix;
  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeading) ...[
          Text('EXAMPLES', style: monoLabel),
          const SizedBox(height: 8),
        ],
        for (var index = 0; index < examples.length; index++) ...[
          _ExampleCard(
            example: examples[index],
            audioRepository: audioRepository,
            audioKey: '$audioKeyPrefix:$index',
          ),
          if (index != examples.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ExampleCard extends ConsumerWidget {
  const _ExampleCard({
    required this.example,
    required this.audioRepository,
    required this.audioKey,
  });

  final LanguageExample example;
  final CardAudioRepository? audioRepository;
  final String audioKey;

  Future<void> _openPhrase(BuildContext context, WidgetRef ref) async {
    final subscription = ref.listenManual(cardsDashboardProvider, (_, _) {});
    final CardsDashboard dashboard;
    try {
      dashboard = await ref.read(cardsDashboardProvider.future);
    } finally {
      subscription.close();
    }
    final phrase = dashboard.cards
        .where(
          (card) => example.cardId != null
              ? card.id == example.cardId
              : card.content is LanguageCardContent &&
                    card.back == example.text &&
                    card.front == example.translation,
        )
        .firstOrNull;
    if (!context.mounted) return;
    if (phrase == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync the library to load this card.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CardDetailsPage(card: phrase, allowEdit: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioUrl = example.audioUrl;
    final palette = RecallPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.soft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => _openPhrase(context, ref),
                  child: Text(
                    example.text,
                    style: const TextStyle(fontSize: 18, height: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                example.transliteration,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: RecallColors.faint,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                example.translation,
                style: const TextStyle(color: RecallColors.muted),
              ),
              if (audioUrl?.isNotEmpty == true && audioRepository != null) ...[
                const SizedBox(height: 10),
                LanguageAudioControls(
                  key: ValueKey('$audioKey:$audioUrl'),
                  audioUrl: audioUrl!,
                  repository: audioRepository!,
                  autoPlay: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
