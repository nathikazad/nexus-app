import 'package:nx_cards/study/language/drawing/native_drawing_session.dart';
import 'package:nx_cards/study/language/drawing/script_draw_practice_page.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/language/language_study_page.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1024, 1366)]) {
    testWidgets('mixed practice Focus view keeps every card at $size', (
      tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        NativeDrawingSession.channel,
        (call) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          NativeDrawingSession.channel,
          null,
        ),
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final original = _card(2, 'cat', '猫', 'māo');
      final cards = [
        _card(1, 'he', '他', 'tā'),
        original.copyWith(
          content: (original.content as LanguageCardContent).copyWith(
            spokenOnly: true,
          ),
        ),
        _card(3, 'she', '她', 'tā'),
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
            home: LanguageStudyPage(title: 'Chinese', cards: cards),
          ),
        ),
      );
      expect(find.byTooltip('Focus view'), findsNWidgets(3));
      expect(
        tester.getCenter(find.byTooltip('Play pronunciation').first).dx,
        lessThan(tester.getCenter(find.byTooltip('Focus view').first).dx),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(3));
      await tester.tap(find.text('he'));
      await tester.pumpAndSettle();
      expect(find.byType(ScriptDrawPracticePage), findsOneWidget);
      expect(find.text('Chinese · Focus'), findsOneWidget);
      final scriptRight = tester
          .getRect(find.byKey(const ValueKey('draw-practice-letter')))
          .right;
      final soundRight = tester
          .getRect(find.byKey(const ValueKey('draw-practice-sound')))
          .right;
      final textRight = scriptRight > soundRight ? scriptRight : soundRight;
      final audioLeft = tester
          .getRect(find.byTooltip('Play pronunciation'))
          .left;
      expect(audioLeft - textRight, inInclusiveRange(0, 24));
      expect(
        find.byKey(const ValueKey('script-drawing-canvas')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Hide character'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      expect(find.text('CARD 2 OF 3'), findsOneWidget);
      expect(find.text('猫'), findsOneWidget);
      expect(find.byKey(const ValueKey('script-drawing-canvas')), findsNothing);
      expect(find.byTooltip('Hide character'), findsNothing);
      expect(find.byTooltip('Play pronunciation'), findsOneWidget);
      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      expect(find.text('CARD 3 OF 3'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('script-drawing-canvas')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Previous'));
      await tester.pumpAndSettle();
      expect(find.text('CARD 2 OF 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('script-drawing-canvas')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows all words on one study sheet without search', (
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
    expect(find.byType(TextField), findsNothing);
    expect(find.text('relief'), findsOneWidget);
    expect(find.text('കഴിവ്'), findsOneWidget);
  });

  testWidgets('uses the shared study sheet for book cards', (tester) async {
    final card = StudyCard(
      id: 3,
      content: const BasicCardContent(
        front: 'What is customer discovery?',
        back: 'Testing hypotheses outside the building.',
      ),
      schedules: {
        for (final direction in StudyCue.values)
          direction: CardSchedule.initial(
            enabled: direction != StudyCue.backToFront,
          ),
        StudyCue.meaningToScript: CardSchedule.initial(enabled: true),
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
    schedules: {
      for (final direction in StudyCue.values)
        direction: CardSchedule.initial(
          enabled: direction != StudyCue.backToFront,
        ),
      StudyCue.meaningToScript: CardSchedule.initial(enabled: true),
      StudyCue.scriptToMeaning: CardSchedule.initial(enabled: true),
      StudyCue.scriptToSound: CardSchedule.initial(enabled: true),
    },
    reviewHistory: const <StudyCue, List<CardReview>>{
      StudyCue.meaningToScript: [],
      StudyCue.scriptToMeaning: [],
      StudyCue.scriptToSound: [],
    },
    suspended: false,
  );
}

class _UnusedAudioRepository implements CardAudioRepository {
  @override
  Future<Uint8List> fetch(String audioUrl) async => Uint8List(0);
}
