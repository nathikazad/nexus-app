import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/study/language_audio_controls.dart';
import 'package:nx_cards/features/study/language_examples.dart';

class CardDetailsDialog extends ConsumerWidget {
  const CardDetailsDialog({super.key, required this.deck, required this.card});

  final CardDeck deck;
  final StudyCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageContent = switch (card.content) {
      final LanguageCardContent content => content,
      _ => null,
    };
    final audioRepository = ref.watch(cardAudioRepositoryProvider);
    final audioUrl = languageContent?.audioUrl;

    return AlertDialog(
      title: const Text('Card details'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(deck.name, style: monoLabel)),
                  if (card.suspended)
                    const _StatusPill(
                      label: 'Suspended',
                      icon: Icons.pause_circle_outline,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _CardField(
                label: languageContent == null ? 'Front' : 'English',
                value: card.front,
              ),
              const SizedBox(height: 16),
              _CardField(
                label: languageContent == null ? 'Back' : 'Original script',
                value: card.back,
                valueStyle: languageContent == null
                    ? null
                    : const TextStyle(fontSize: 24, height: 1.45),
              ),
              if (languageContent != null) ...[
                const SizedBox(height: 16),
                _CardField(
                  label: 'Transliteration',
                  value: languageContent.transliteration,
                  valueStyle: const TextStyle(
                    fontSize: 17,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (audioUrl?.isNotEmpty == true &&
                    audioRepository != null) ...[
                  const SizedBox(height: 18),
                  Text('PRONUNCIATION', style: monoLabel),
                  const SizedBox(height: 8),
                  LanguageAudioControls(
                    key: ValueKey('${card.id}:details:$audioUrl'),
                    audioUrl: audioUrl!,
                    repository: audioRepository,
                    autoPlay: false,
                  ),
                ],
                if (languageContent.examples.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  LanguageExamples(
                    examples: languageContent.examples,
                    audioRepository: audioRepository,
                    audioKeyPrefix: '${card.id}:details:example',
                  ),
                ],
              ],
              if (card.tags.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('TAGS', style: monoLabel),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final tag in card.tags) Chip(label: Text(tag)),
                  ],
                ),
              ],
              if (card.sourceBookName case final sourceBook?) ...[
                const SizedBox(height: 20),
                _CardField(label: 'Source book', value: sourceBook),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit card'),
        ),
      ],
    );
  }
}

class _CardField extends StatelessWidget {
  const _CardField({required this.label, required this.value, this.valueStyle});

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RecallColors.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RecallColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: monoLabel),
            const SizedBox(height: 7),
            SelectableText(
              value,
              style: valueStyle ?? const TextStyle(fontSize: 18, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: RecallColors.soft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: RecallColors.faint),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: RecallColors.muted),
          ),
        ],
      ),
    );
  }
}
