import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/domain/card/card_audio_repository.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/study/study_screen.dart';

void main() {
  testWidgets(
    'English Script recall uses drawing and reveals the right letter',
    (tester) async {
      final card = _scriptCard();
      await _pumpRecall(tester, card, StudyCue.fromLanguage);

      expect(find.text('ka'), findsOneWidget);
      expect(find.byTooltip('Play pronunciation'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('script-drawing-canvas')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('script-recall-answer')),
        findsNothing,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Show answer'),
            )
            .onPressed,
        isNull,
      );

      await tester.drag(
        find.byKey(const ValueKey<String>('script-drawing-canvas')),
        const Offset(80, 80),
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Show answer'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('script-recall-answer')),
        findsOneWidget,
      );
      expect(find.text('ക'), findsOneWidget);
      expect(find.text('ka'), findsNothing);
      expect(find.text('Compare your drawing with the answer'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('script-drawing-canvas')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Malayalam Script recall keeps the standard reveal flow', (
    tester,
  ) async {
    final card = _scriptCard();
    await _pumpRecall(tester, card, StudyCue.toLanguage);

    expect(find.text('ക'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('script-drawing-canvas')),
      findsNothing,
    );
    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();

    expect(find.text('Letter ka'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
  });
}

Future<void> _pumpRecall(
  WidgetTester tester,
  StudyCard card,
  StudyCue cue,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cardAudioRepositoryProvider.overrideWithValue(
          cue == StudyCue.fromLanguage ? _FakeAudioRepository() : null,
        ),
        cardsDashboardProvider.overrideWith(
          (_) => Stream.value(const CardsDashboard(cards: [])),
        ),
      ],
      child: MaterialApp(
        home: StudyScreen(
          title: 'Malayalam Script',
          prompts: [StudyPrompt(card: card, cue: cue)],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

StudyCard _scriptCard() => StudyCard(
  id: 1,
  content: const LanguageCardContent(
    english: 'Letter ka',
    originalScript: 'ക',
    transliteration: 'ka',
    audioUrl: '/audio/ka.mp3',
  ),
  schedules: const <StudyCue, CardSchedule>{
    StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
    StudyCue.toLanguage: CardSchedule.initial(enabled: true),
  },
  reviewHistory: const <StudyCue, List<CardReview>>{
    StudyCue.fromLanguage: <CardReview>[],
    StudyCue.toLanguage: <CardReview>[],
  },
  suspended: false,
  learningStatus: LearningStatus.learning,
  modelTypeName: 'Script',
);

class _FakeAudioRepository implements CardAudioRepository {
  @override
  Future<Uint8List> fetch(String audioUrl) async => Uint8List(0);
}
