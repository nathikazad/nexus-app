import 'package:nx_cards/study/language/language_examples_page.dart';
import 'package:nx_cards/study/language/tablet_recall_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/study/session/study_session_page.dart';

StudyCard card(
  int id,
  String script,
  String meaning, {
  Set<int> links = const {},
  List<LanguageExample> examples = const [],
}) => StudyCard(
  id: id,
  content: LanguageCardContent(
    english: meaning,
    originalScript: script,
    transliteration: 'sound',
    examples: examples,
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
  linkedWordIds: links,
);

class Library implements CardLibrary {
  Library(this.cards);
  final List<StudyCard> cards;
  @override
  Future<List<StudyCard>> listCards() async => cards;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'phone examples page includes available Examples Contains and Similar tabs',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final original = card(
        10,
        '猫狗',
        'pets',
        links: {11},
        examples: const [
          LanguageExample(
            text: '例子',
            transliteration: 'li zi',
            translation: 'An example',
          ),
        ],
      );
      final target = original.copyWith(
        learningStatus: LearningStatus.recall,
        content: (original.content as LanguageCardContent).copyWith(
          similarWordGroups: ['pets-write'],
        ),
      );
      final other = card(12, '狗', 'dog');
      final peer = other.copyWith(
        learningStatus: LearningStatus.recall,
        content: (other.content as LanguageCardContent).copyWith(
          similarWordGroups: ['pets-write'],
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardAudioRepositoryProvider.overrideWithValue(null),
            cardLibraryProvider.overrideWithValue(
              Library([target, card(11, '猫', 'cat'), peer]),
            ),
          ],
          child: MaterialApp(
            home: LanguageExamplesPage(card: target, audioRepository: null),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tabs = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(tabs.segments.map((s) => s.value), [
        'Examples',
        'Contains',
        'Similar',
      ]);
      await tester.tap(find.text('Contains'));
      await tester.pumpAndSettle();
      expect(find.text('cat'), findsOneWidget);
      await tester.tap(find.text('Similar'));
      await tester.pumpAndSettle();
      expect(find.text('dog'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Similar alone has no empty tabs and shows full groups', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = card(1, '了', 'completion');
    final target = original.copyWith(
      learningStatus: LearningStatus.recall,
      content: (original.content as LanguageCardContent).copyWith(
        similarWordGroups: ['particle-other'],
      ),
    );
    final originalPeer = card(2, '着', 'continuing state');
    final peer = originalPeer.copyWith(
      learningStatus: LearningStatus.recall,
      content: (originalPeer.content as LanguageCardContent).copyWith(
        similarWordGroups: ['particle-other'],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardLibraryProvider.overrideWithValue(Library([target, peer])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TabletRecallContext(card: target),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('particle'), findsOneWidget);
    expect(find.text('continuing state'), findsOneWidget);
    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(find.text('Examples'), findsNothing);
    expect(find.text('Contains'), findsNothing);
  });

  for (final tablet in [false, true]) {
    testWidgets(
      'revealed context is tablet-only ($tablet) and hidden before reveal',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = tablet
            ? const Size(1100, 900)
            : const Size(390, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final target = card(
          1,
          '猫狗',
          'pets',
          links: {2, 3},
          examples: const [
            LanguageExample(
              text: '例子',
              transliteration: 'lìzi',
              translation: 'A linked example',
            ),
          ],
        );
        final cards = [target, card(2, '猫', 'cat'), card(3, '狗', 'dog')];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cardAudioRepositoryProvider.overrideWithValue(null),
              cardLibraryProvider.overrideWithValue(Library(cards)),
              cardsDashboardProvider.overrideWith(
                (_) => Stream.value(CardsDashboard(cards: cards)),
              ),
            ],
            child: MaterialApp(
              home: StudySessionPage(
                title: 'Chinese',
                prompts: [
                  StudyPrompt(card: target, cue: StudyCue.meaningToScript),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Contains'), findsNothing);
        expect(find.text('A linked example'), findsNothing);
        await tester.tap(find.textContaining('Show answer').first);
        await tester.pumpAndSettle();
        expect(find.text('Contains'), tablet ? findsOneWidget : findsNothing);
        expect(
          find.text('A linked example'),
          tablet ? findsOneWidget : findsNothing,
        );
        expect(find.text('cat'), findsNothing);
        if (tablet) {
          await tester.ensureVisible(find.text('Contains'));
          await tester.tap(find.text('Contains'));
          await tester.pumpAndSettle();
          expect(find.text('cat'), findsOneWidget);
          expect(find.text('A linked example'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
