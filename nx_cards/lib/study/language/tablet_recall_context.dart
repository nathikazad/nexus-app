import 'package:nx_cards/browser/language/similar_sounds_page.dart';
import 'package:nx_cards/study/language/similar_sounds.dart';
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
  const TabletRecallContext({
    super.key,
    required this.card,
    this.allSizes = false,
  });
  final StudyCard card;
  final bool allSizes;

  static bool visibleOn(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600;

  @override
  ConsumerState<TabletRecallContext> createState() =>
      _TabletRecallContextState();
}

class _TabletRecallContextState extends ConsumerState<TabletRecallContext> {
  String? _selected;
  List<SimilarSoundGroup> _similar = const [];
  List<LanguageCardContent> _parts = const [];
  Map<LanguageCardContent, int> _partIds = const {};
  List<DerivedLanguageExample> _derived = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final content = widget.card.content;
    if (content is! LanguageCardContent) {
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
      final parts = NativeDrawingSession.characterCards(widget.card, {
        for (final card in library) card.id: card,
      });
      if (mounted) {
        setState(() {
          _parts = [
            for (final part in parts) part.content as LanguageCardContent,
          ];
          _partIds = {
            for (final part in parts)
              part.content as LanguageCardContent: part.id,
          };
          _similar = similarGroupsForCard(widget.card, library);
          _derived = NativeDrawingSession.derivedExamples(widget.card, linked);
        });
      }
    } catch (_) {
      // Keep any directly available examples if linked cards cannot load.
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.card.content;
    if (content is! LanguageCardContent ||
        (!widget.allSizes && !TabletRecallContext.visibleOn(context))) {
      return const SizedBox.shrink();
    }
    final audio = ref.watch(cardAudioRepositoryProvider);
    final sections = <String, Widget>{
      if (content.examples.isNotEmpty || _derived.isNotEmpty)
        'Examples': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (content.examples.isNotEmpty)
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
      if (_parts.isNotEmpty)
        'Contains': LanguageExamples(
          examples: [
            for (final part in _parts)
              LanguageExample(
                cardId: _partIds[part],
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
      if (_similar.isNotEmpty) 'Similar': SimilarWordGroups(groups: _similar),
    };
    if (sections.isEmpty) return const SizedBox.shrink();
    final selected = sections.containsKey(_selected)
        ? _selected!
        : sections.keys.first;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sections.length > 1) ...[
            SegmentedButton<String>(
              segments: [
                for (final title in sections.keys)
                  ButtonSegment(value: title, label: Text(title)),
              ],
              selected: {selected},
              showSelectedIcon: false,
              onSelectionChanged: (values) =>
                  setState(() => _selected = values.single),
            ),
            const SizedBox(height: 12),
          ],
          sections[selected]!,
        ],
      ),
    );
  }
}
