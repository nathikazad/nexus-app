import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/study/language/drawing/native_drawing_session.dart';
import 'package:nx_cards/study/language/language_examples.dart';

/// Only mount after reveal. Uses the same saved character links as study.
class TabletRecallContext extends ConsumerStatefulWidget {
  const TabletRecallContext({super.key, required this.card});
  final StudyCard card;

  static bool visibleOn(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600;

  @override
  ConsumerState<TabletRecallContext> createState() =>
      _TabletRecallContextState();
}

class _TabletRecallContextState extends ConsumerState<TabletRecallContext> {
  List<LanguageCardContent> _parts = const [];
  List<DerivedLanguageExample> _derived = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final content = widget.card.content;
    if (content is! LanguageCardContent) {
      _loading = false;
      return;
    }
    try {
      final library = await ref.read(cardLibraryProvider).listCards();
      final linked = {for (final card in library) card.id: card};
      await NativeDrawingSession.hydrateExampleParents(
        [widget.card],
        linked,
        (card) => hydrateStudyCard(ref, card),
      );
      final parts = NativeDrawingSession.characterParts(widget.card, {
        for (final card in library) card.id: card,
      });
      if (mounted) {
        setState(() {
          _parts = parts;
          _derived = NativeDrawingSession.derivedExamples(widget.card, linked);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.card.content;
    if (content is! LanguageCardContent ||
        !TabletRecallContext.visibleOn(context)) {
      return const SizedBox.shrink();
    }
    final audio = ref.watch(cardAudioRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('USED IN · EXAMPLES', style: monoLabel),
                const SizedBox(height: 8),
                if (content.examples.isEmpty)
                  const Text('No linked examples for this card yet.')
                else
                  LanguageExamples(
                    examples: content.examples,
                    audioRepository: audio,
                    audioKeyPrefix: 'recall-examples:${widget.card.id}',
                    showHeading: false,
                  ),
                if (_derived.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('DERIVED EXAMPLES', style: monoLabel),
                  for (final entry in _derived) ...[
                    const SizedBox(height: 8),
                    Text('Via ${entry.via.join(', ')}'),
                    LanguageExamples(
                      examples: [entry.example],
                      audioRepository: audio,
                      audioKeyPrefix:
                          'recall-derived:${widget.card.id}:${entry.example.cardId}:${entry.example.text}',
                      showHeading: false,
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (content.originalScript.trim().characters.length > 1) ...[
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('CHARACTERS', style: monoLabel),
                  const SizedBox(height: 8),
                  if (_loading)
                    const LinearProgressIndicator()
                  else if (_parts.isEmpty)
                    Text(
                      _failed
                          ? 'Could not load linked characters.'
                          : 'No linked characters yet.',
                    )
                  else
                    LanguageExamples(
                      examples: [
                        for (final part in _parts)
                          LanguageExample(
                            text: part.originalScript,
                            transliteration: part.transliteration,
                            translation: part.english,
                            audioUrl: part.audioUrl,
                          ),
                      ],
                      audioRepository: audio,
                      audioKeyPrefix: 'recall-characters:${widget.card.id}',
                      showHeading: false,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
