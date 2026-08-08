import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/domain/card/card_audio_repository.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/study/language_study_page.dart';

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
    deckId: 7,
    deckName: 'Malayalam',
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
