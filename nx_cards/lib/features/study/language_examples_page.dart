import 'package:flutter/material.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/domain/card/card_audio_repository.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/study/language_examples.dart';

class LanguageExamplesPage extends StatelessWidget {
  const LanguageExamplesPage({
    super.key,
    required this.card,
    required this.audioRepository,
  });

  final StudyCard card;
  final CardAudioRepository? audioRepository;

  @override
  Widget build(BuildContext context) {
    final content = card.content;
    if (content is! LanguageCardContent) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 104,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Review'),
        ),
        title: const Text('Examples'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              children: [
                Text(card.deckName.toUpperCase(), style: monoLabel),
                const SizedBox(height: 16),
                Text(
                  content.originalScript,
                  style: const TextStyle(
                    fontSize: 32,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content.transliteration,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                    color: RecallColors.faint,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content.english,
                  style: const TextStyle(
                    fontSize: 18,
                    color: RecallColors.muted,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(),
                ),
                LanguageExamples(
                  examples: content.examples,
                  audioRepository: audioRepository,
                  audioKeyPrefix: '${card.id}:examples-page',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
