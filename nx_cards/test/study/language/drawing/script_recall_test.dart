import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/session/study_session_page.dart';
import 'package:nx_cards/study/language/drawing/recall_interaction.dart';

void main() {
  testWidgets(
    'English Script recall uses drawing and reveals the right letter',
    (tester) async {
      final card = _scriptCard();
      await _pumpRecall(tester, card, StudyCue.fromLanguage, writing: true);

      expect(find.text('Letter ka'), findsOneWidget);
      expect(find.byTooltip('Play pronunciation'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('script-drawing-canvas')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('writing-recall-answer')),
        findsNothing,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Show answer'),
            )
            .onPressed,
        isNotNull,
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
        find.byKey(const ValueKey<String>('writing-recall-answer')),
        findsOneWidget,
      );
      expect(find.text('ക'), findsOneWidget);
      expect(find.text('ka'), findsOneWidget);
      expect(find.text('Compare your drawing with the answer'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('script-drawing-canvas')),
        findsOneWidget,
      );
    },
  );

  for (final language in ['Chinese', 'Malayalam', 'Spanish']) {
    for (final type in ['Word', 'Verb', 'Phrase', 'Script']) {
      for (final cue in StudyCue.values) {
        testWidgets('$language $type can write with ${cue.name}', (
          tester,
        ) async {
          final card = StudyCard(
            id: 2,
            modelTypeName: type,
            tags: {
              'Language': [language],
            },
            content: const LanguageCardContent(
              english: 'student',
              originalScript: '学生',
              transliteration: 'xuésheng',
            ),
            schedules: {
              for (final c in StudyCue.values)
                c: const CardSchedule.initial(enabled: true),
            },
            reviewHistory: {},
            suspended: false,
          );
          await _pumpRecall(tester, card, cue, writing: true);
          expect(
            find.text(StudyPrompt(card: card, cue: cue).prompt),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('script-drawing-canvas')),
            findsOneWidget,
          );
          // A forgotten answer must still be revealable without drawing.
          await tester.tap(find.text('Show answer'));
          await tester.pumpAndSettle();
          final answer = tester.widget<Text>(
            find.byKey(const ValueKey('writing-recall-answer')),
          );
          expect(answer.data, cue == StudyCue.fromLanguage ? '学生' : 'student');
          expect(find.text('Yes'), findsOneWidget);
          expect(find.text('No'), findsOneWidget);
        });
      }
    }
  }

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
  StudyCue cue, {
  bool writing = false,
}) async {
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
        home: StudySessionPage(
          title: 'Malayalam Script',
          interaction: writing
              ? RecallInteraction.writing
              : RecallInteraction.standard,
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
