import 'package:nx_cards/account/account_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/card_details_page.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/study/language/similar_sounds.dart';
import 'native_drawing_session.dart';
import 'script_draw_practice_page.dart';

Future<void> openSheetDrawing(
  BuildContext context,
  WidgetRef ref,
  String title,
  List<StudyCard> cards,
  int initialIndex,
) async {
  final audio = ref.read(cardAudioRepositoryProvider);
  try {
    if (!await NativeDrawingSession.isAvailable()) {
      if (!context.mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ScriptDrawPracticePage(
            title: title,
            cards: cards,
            initialIndex: initialIndex,
            audioRepository: audio,
          ),
        ),
      );
      return;
    }
    final sessionKey = ref.read(activeCardsSessionProvider).value?.account.key;
    final linkedLibrary = {
      for (final card in await ref.read(cardLibraryProvider).listCards())
        card.id: card,
    };
    await NativeDrawingSession.hydrateExampleParents(
      cards,
      linkedLibrary,
      (card) => hydrateStudyCard(ref, card),
    );
    final parts = [
      for (final card in cards)
        NativeDrawingSession.characterCards(card, linkedLibrary),
    ];
    final characters = [
      for (final list in parts)
        [for (final part in list) part.content as LanguageCardContent],
    ];
    final characterCardIds = {
      for (final list in parts)
        for (final part in list) part.content as LanguageCardContent: part.id,
    };
    final derived = [
      for (final card in cards)
        NativeDrawingSession.derivedExamples(card, linkedLibrary),
    ];
    if (!context.mounted ||
        sessionKey != ref.read(activeCardsSessionProvider).value?.account.key) {
      return;
    }
    await NativeDrawingSession.open(
      title: title,
      recall: false,
      initialIndex: initialIndex,
      cards: [
        for (var i = 0; i < cards.length; i++)
          NativeDrawingSession.practiceCard(
            cards[i],
            similar: similarGroupsForCard(cards[i], linkedLibrary.values),
            characters: characters[i],
            characterCardIds: characterCardIds,
            derived: derived[i],
          ),
      ],
      onAction: (call) async {
        if (!context.mounted ||
            sessionKey !=
                ref.read(activeCardsSessionProvider).value?.account.key) {
          throw PlatformException(code: 'session_changed');
        }
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        final index = args['index'] as int;
        if (index < 0 || index >= cards.length) {
          throw PlatformException(code: 'invalid_card');
        }
        if (call.method == 'exampleCard') {
          final targetId = args['cardId'];
          final parent = cards[index].content as LanguageCardContent;
          final permitted = {
            ...parent.examples.map((e) => e.cardId),
            ...characters[index].map((part) => characterCardIds[part]),
            ...derived[index].map((e) => e.example.cardId),
            ...similarGroupsForCard(
              cards[index],
              linkedLibrary.values,
            ).expand((g) => g.cards).map((c) => c.id),
          };
          final target = targetId is int ? linkedLibrary[targetId] : null;
          if (target == null ||
              target.content is! LanguageCardContent ||
              !permitted.contains(targetId)) {
            throw PlatformException(
              code: 'example_unavailable',
              message: 'This example card is not available.',
            );
          }
          final details = Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => CardDetailsPage(card: target)),
          );
          try {
            await NativeDrawingSession.channel.invokeMethod<void>(
              'showFlutter',
            );
            await details;
          } finally {
            await NativeDrawingSession.channel.invokeMethod<void>(
              'resumeDrawing',
            );
          }
          return null;
        }
        if (call.method == 'audio') {
          final content = cards[index].content as LanguageCardContent;
          final exampleIndex = args['exampleIndex'];
          final characterIndex = args['characterIndex'];
          final derivedIndex = args['derivedIndex'];
          final similarCardId = args['similarCardId'];
          if ([
                exampleIndex,
                characterIndex,
                derivedIndex,
                similarCardId,
              ].where((v) => v != null).length >
              1) {
            throw PlatformException(code: 'invalid_audio_target');
          }
          var audioUrl = content.audioUrl;
          if (similarCardId != null) {
            final target =
                similarGroupsForCard(cards[index], linkedLibrary.values)
                    .expand((g) => g.cards)
                    .where((c) => c.id == similarCardId)
                    .firstOrNull;
            if (target?.content case final LanguageCardContent word) {
              audioUrl = word.audioUrl;
            } else {
              throw PlatformException(code: 'invalid_similar_card');
            }
          }
          if (derivedIndex != null) {
            if (derivedIndex is! int ||
                derivedIndex < 0 ||
                derivedIndex >= derived[index].length) {
              throw PlatformException(code: 'invalid_derived_example');
            }
            audioUrl = derived[index][derivedIndex].example.audioUrl;
          }
          if (exampleIndex != null) {
            final examples = content.examples;
            if (exampleIndex is! int ||
                exampleIndex < 0 ||
                exampleIndex >= examples.length) {
              throw PlatformException(code: 'invalid_example');
            }
            audioUrl = examples[exampleIndex].audioUrl;
          }
          if (characterIndex != null) {
            if (exampleIndex != null ||
                characterIndex is! int ||
                characterIndex < 0 ||
                characterIndex >= characters[index].length) {
              throw PlatformException(code: 'invalid_character');
            }
            audioUrl = characters[index][characterIndex].audioUrl;
          }
          if (audio == null || audioUrl == null || audioUrl.trim().isEmpty) {
            throw PlatformException(code: 'audio_unavailable');
          }
          return audio.fetch(audioUrl);
        }
        return null;
      },
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open drawing practice. Please try again.'),
        ),
      );
    }
  }
}
