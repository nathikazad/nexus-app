import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/study/language/grouped_recall_page.dart';
import 'package:nx_cards/study/language/drawing/native_drawing_session.dart';
import 'package:nx_cards/study/language/similar_sounds.dart';
import 'similar_sounds_test.dart' show soundCard;

class RecordingLibrary implements CardLibrary {
  final saved = <StudyCard>[];
  int? failId;
  @override
  Future<void> saveSchedule(StudyCard card) async {
    if (card.id == failId) throw StateError('offline');
    saved.add(card);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> showGroups(
  WidgetTester tester,
  RecordingLibrary library,
  List<SimilarRecallGroup> groups,
  GroupedRecallFormat format,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    NativeDrawingSession.channel,
    (call) async => call.method == 'available' ? false : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      NativeDrawingSession.channel,
      null,
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cardLibraryProvider.overrideWithValue(library),
        cardAudioRepositoryProvider.overrideWithValue(null),
        cardsInvalidationProvider.overrideWith((ref) => () {}),
      ],
      child: MaterialApp(
        home: GroupedRecallPage(groups: groups, format: format),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> answerWord(WidgetTester tester) async {
  final action = find.byKey(const ValueKey('group-question-next'));
  await tester.tap(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

void main() {
  for (final format in GroupedRecallFormat.values) {
    testWidgets(
      '${format.name} collects answers without grades, then one decision grades only tested words',
      (tester) async {
        final library = RecordingLibrary();
        final cards = [
          soundCard(1, 'guó'),
          soundCard(2, 'guǒ'),
          soundCard(3, 'guò'),
        ];
        await showGroups(tester, library, [
          SimilarRecallGroup(
            prompts: [
              for (final c in cards.take(2))
                StudyPrompt(card: c, cue: StudyCue.fromAudio),
            ],
            comparisonCards: cards,
          ),
        ], format);
        expect(find.byKey(const ValueKey('group-recalled')), findsNothing);
        await answerWord(tester);
        expect(library.saved, isEmpty);
        await answerWord(tester);
        expect(library.saved, isEmpty);
        expect(find.text('Compare words'), findsOneWidget);
        expect(find.text('Not asked'), findsOneWidget);
        for (final c in cards) {
          expect(find.text(c.front), findsOneWidget);
        }
        await tester.tap(find.byKey(const ValueKey('group-recalled')));
        await tester.pumpAndSettle();
        expect(library.saved.map((c) => c.id), [1, 2]);
        expect(
          library.saved.every(
            (c) => c.reviewHistoryFor(StudyCue.fromAudio).single.rating == 3,
          ),
          isTrue,
        );
        expect(find.text('Group recalled'), findsOneWidget);
        await tester.tap(find.text('Finish'));
        await tester.pumpAndSettle();
        expect(find.text('2 recalled'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'negative group decision applies to every word; practice retry writes nothing',
    (tester) async {
      final library = RecordingLibrary();
      final cards = [soundCard(1, 'yóu'), soundCard(2, 'yóu')];
      await showGroups(tester, library, [
        SimilarRecallGroup(
          prompts: [
            for (final c in cards)
              StudyPrompt(card: c, cue: StudyCue.fromLanguage),
          ],
          comparisonCards: cards,
        ),
      ], GroupedRecallFormat.standard);
      await answerWord(tester);
      await answerWord(tester);
      await tester.tap(find.byKey(const ValueKey('group-not-recalled')));
      await tester.pumpAndSettle();
      expect(
        library.saved.every(
          (c) => c.reviewHistoryFor(StudyCue.fromLanguage).single.rating == 1,
        ),
        isTrue,
      );
      await tester.tap(find.text('Retry group'));
      await tester.pumpAndSettle();
      await answerWord(tester);
      await answerWord(tester);
      await tester.tap(find.byKey(const ValueKey('group-recalled')));
      await tester.pumpAndSettle();
      expect(library.saved, hasLength(2));
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(find.text('2 not recalled'), findsOneWidget);
    },
  );
  testWidgets(
    'save failure offers retry; next group keeps earlier history on repeated word',
    (tester) async {
      final library = RecordingLibrary()..failId = 2;
      final a = soundCard(1, 'guó'),
          b = soundCard(2, 'guǒ'),
          c = soundCard(3, 'gǒu');
      await showGroups(tester, library, [
        SimilarRecallGroup(
          prompts: [
            for (final x in [a, b])
              StudyPrompt(card: x, cue: StudyCue.fromLanguage),
          ],
          comparisonCards: [a, b],
        ),
        SimilarRecallGroup(
          prompts: [
            for (final x in [a, c])
              StudyPrompt(card: x, cue: StudyCue.fromLanguage),
          ],
          comparisonCards: [a, c],
        ),
      ], GroupedRecallFormat.fast);
      await answerWord(tester);
      await answerWord(tester);
      await tester.tap(find.byKey(const ValueKey('group-recalled')));
      await tester.pumpAndSettle();
      expect(library.saved.map((c) => c.id), [1]);
      expect(find.text('Retry saving'), findsOneWidget);
      library.failId = null;
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect(library.saved.map((c) => c.id), [1, 2]);
      await tester.tap(find.text('Next group'));
      await tester.pumpAndSettle();
      await answerWord(tester);
      await answerWord(tester);
      await tester.tap(find.byKey(const ValueKey('group-not-recalled')));
      await tester.pumpAndSettle();
      expect(
        library.saved[2]
            .reviewHistoryFor(StudyCue.fromLanguage)
            .map((r) => r.rating),
        [3, 1],
      );
    },
  );
}
