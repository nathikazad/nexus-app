import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/language/language_study_page.dart';

void main() {
  testWidgets('shows and searches all words on one study sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cards = [
      _card(1, 'relief', 'ആശ്വാസം', 'āśvāsaṃ'),
      _card(2, 'talent', 'കഴിവ്', 'kaḻiv'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(
            _UnusedAudioRepository(),
          ),
        ],
        child: MaterialApp(
          theme: buildRecallTheme(),
          home: LanguageStudyPage(title: 'Malayalam', cards: cards),
        ),
      ),
    );

    expect(find.text('2 words'), findsOneWidget);
    expect(find.text('relief'), findsOneWidget);
    expect(find.text('talent'), findsOneWidget);
    expect(find.text('Examples'), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), 'talent');
    await tester.pump();

    expect(find.text('1 of 2 words'), findsOneWidget);
    expect(find.text('relief'), findsNothing);
    expect(find.text('കഴിവ്'), findsOneWidget);
  });

  testWidgets('uses the shared study sheet for book cards', (tester) async {
    final card = StudyCard(
      id: 3,
      content: const BasicCardContent(
        front: 'What is customer discovery?',
        back: 'Testing hypotheses outside the building.',
      ),
      schedules: const {
        StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
      },
      reviewHistory: const {},
      suspended: false,
      sourceBookId: 4195,
      sourceBookName: 'The Four Steps to the Epiphany',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [cardAudioRepositoryProvider.overrideWithValue(null)],
        child: MaterialApp(
          home: LanguageStudyPage(
            title: 'The Four Steps to the Epiphany',
            cards: [card],
            itemLabel: 'cards',
          ),
        ),
      ),
    );

    expect(find.text('1 cards'), findsOneWidget);
    expect(find.text('What is customer discovery?'), findsOneWidget);
    expect(
      find.text('Testing hypotheses outside the building.'),
      findsOneWidget,
    );
    expect(find.text('Examples'), findsNothing);
  });
}

StudyCard _card(int id, String english, String script, String transliteration) {
  return StudyCard(
    id: id,
    content: LanguageCardContent(
      english: english,
      originalScript: script,
      transliteration: transliteration,
      audioUrl: '/audio/$id.mp3',
      examples: const [
        LanguageExample(
          text: 'ഉദാഹരണം',
          transliteration: 'udāharaṇaṃ',
          translation: 'example',
        ),
      ],
    ),
    schedules: const <StudyCue, CardSchedule>{
      StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
      StudyCue.toLanguage: CardSchedule.initial(enabled: true),
      StudyCue.transliteration: CardSchedule.initial(enabled: true),
    },
    reviewHistory: const <StudyCue, List<CardReview>>{
      StudyCue.fromLanguage: [],
      StudyCue.toLanguage: [],
      StudyCue.transliteration: [],
    },
    suspended: false,
  );
}

class _UnusedAudioRepository implements CardAudioRepository {
  @override
  Future<Uint8List> fetch(String audioUrl) async => Uint8List(0);
}
