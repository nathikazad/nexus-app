import 'package:flutter/material.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/language/language_audio_controls.dart';

class LanguageExamples extends StatelessWidget {
  const LanguageExamples({
    super.key,
    required this.examples,
    required this.audioRepository,
    required this.audioKeyPrefix,
  });

  final List<LanguageExample> examples;
  final CardAudioRepository? audioRepository;
  final String audioKeyPrefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('EXAMPLES', style: monoLabel),
        const SizedBox(height: 8),
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

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.example,
    required this.audioRepository,
    required this.audioKey,
  });

  final LanguageExample example;
  final CardAudioRepository? audioRepository;
  final String audioKey;

  @override
  Widget build(BuildContext context) {
    final audioUrl = example.audioUrl;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RecallColors.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RecallColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              example.text,
              style: const TextStyle(fontSize: 18, height: 1.4),
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
    );
  }
}
