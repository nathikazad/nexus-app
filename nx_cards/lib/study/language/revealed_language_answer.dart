import 'package:flutter/material.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/language/language_audio_controls.dart';

/// The answer is the complete word, regardless of the direction being tested.
class RevealedLanguageAnswer extends StatelessWidget {
  const RevealedLanguageAnswer({
    super.key,
    required this.content,
    this.audioRepository,
    this.compact = false,
    this.autoPlay = true,
  });
  final LanguageCardContent content;
  final CardAudioRepository? audioRepository;
  final bool compact;
  final bool autoPlay;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: compact
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        content.originalScript,
        textAlign: compact ? TextAlign.start : TextAlign.center,
        style: TextStyle(
          fontSize: compact ? 22 : 38,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        content.transliteration,
        textAlign: compact ? TextAlign.start : TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          height: 1.35,
          color: RecallColors.muted,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        content.english,
        textAlign: compact ? TextAlign.start : TextAlign.center,
        style: TextStyle(fontSize: compact ? 16 : 20, height: 1.35),
      ),
      if (content.audioUrl?.trim().isNotEmpty == true &&
          audioRepository != null)
        PronunciationButton(
          audioUrl: content.audioUrl!,
          repository: audioRepository!,
          autoPlay: autoPlay,
        ),
    ],
  );
}
