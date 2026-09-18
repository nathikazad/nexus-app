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
  schedules: const {StudyCue.fromLanguage: CardSchedule.initial(enabled: true)},
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
                  StudyPrompt(card: target, cue: StudyCue.fromLanguage),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('USED IN · EXAMPLES'), findsNothing);
        expect(find.text('A linked example'), findsNothing);
        await tester.tap(find.textContaining('Show answer').first);
        await tester.pumpAndSettle();
        expect(
          find.text('USED IN · EXAMPLES'),
          tablet ? findsOneWidget : findsNothing,
        );
        expect(find.text('CHARACTERS'), tablet ? findsOneWidget : findsNothing);
        expect(
          find.text('A linked example'),
          tablet ? findsOneWidget : findsNothing,
        );
        expect(find.text('cat'), tablet ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
