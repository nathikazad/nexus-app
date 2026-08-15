import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/session/study_session_page.dart';

void main() {
  testWidgets('recall completion recaps every word in all three forms', (
    tester,
  ) async {
    final card = StudyCard(
      id: 1,
      content: const LanguageCardContent(
        english: 'talent',
        originalScript: 'കഴിവ്',
        transliteration: 'kazhivu',
      ),
      schedules: const {
        StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
      },
      reviewHistory: const {},
      suspended: false,
      learningStatus: LearningStatus.learning,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(const CardsDashboard(cards: [])),
          ),
        ],
        child: MaterialApp(
          home: StudySessionPage(
            title: 'Malayalam',
            prompts: [StudyPrompt(card: card, cue: StudyCue.fromLanguage)],
          ),
        ),
      ),
    );
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();

    expect(find.text('WORDS'), findsOneWidget);
    expect(find.text('talent'), findsOneWidget);
    expect(find.text('കഴിവ്'), findsOneWidget);
    expect(find.text('kazhivu'), findsOneWidget);
    expect(find.text('NOT REVIEWED'), findsOneWidget);
  });

  testWidgets('recall recap uses a readable dark surface', (tester) async {
    final card = StudyCard(
      id: 1,
      content: const LanguageCardContent(
        english: 'talent',
        originalScript: 'കഴിവ്',
        transliteration: 'kazhivu',
      ),
      schedules: const {
        StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
      },
      reviewHistory: const {},
      suspended: false,
      learningStatus: LearningStatus.learning,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(const CardsDashboard(cards: [])),
          ),
        ],
        child: MaterialApp(
          theme: buildRecallTheme(),
          darkTheme: buildRecallDarkTheme(),
          themeMode: ThemeMode.dark,
          home: StudySessionPage(
            title: 'Malayalam',
            prompts: [StudyPrompt(card: card, cue: StudyCue.fromLanguage)],
          ),
        ),
      ),
    );
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();

    final recap = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('recall-word-recap')),
    );
    final decoration = recap.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xff18181b));
    expect(decoration.color, isNot(const Color(0xfff4f4f5)));
  });
}
