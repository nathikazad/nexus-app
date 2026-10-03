import 'package:nx_cards/study/session/recall_recap_page.dart';
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

Future<void> answerWord(WidgetTester tester, {bool correct = true}) async {
  await tester.tap(find.byKey(const ValueKey('group-question-next')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(ValueKey(correct ? 'group-recalled' : 'group-not-recalled')),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'mixed writing group skips the spoken card canvas and grades only its oral cue',
    (tester) async {
      final original = soundCard(1, 'a');
      final spoken = original.copyWith(
        content: (original.content as LanguageCardContent).copyWith(
          spokenOnly: true,
        ),
      );
      final written = soundCard(2, 'b');
      final library = RecordingLibrary();
      await showGroups(
        tester,
        library,
        [
          SimilarRecallGroup(
            prompts: [
              StudyPrompt(card: spoken, cue: StudyCue.fromLanguage),
              StudyPrompt(card: written, cue: StudyCue.fromLanguage),
            ],
            comparisonCards: [spoken, written],
          ),
        ],
        GroupedRecallFormat.values.firstWhere(
          (v) => v != GroupedRecallFormat.fast,
        ),
      );
      expect(find.byKey(const ValueKey('script-drawing-canvas')), findsNothing);
      await answerWord(tester);
      expect(library.saved.single.spokenOnly, isTrue);
      expect(
        library.saved.single.reviewHistoryFor(StudyCue.toLanguage),
        isEmpty,
      );
      expect(
        find.byKey(const ValueKey('script-drawing-canvas')),
        findsOneWidget,
      );
    },
  );

  for (final format in GroupedRecallFormat.values) {
    testWidgets(
      '${format.name} grades each word immediately; comparison writes nothing',
      (tester) async {
        final library = RecordingLibrary();
        final cards = [soundCard(1, 'a'), soundCard(2, 'b'), soundCard(3, 'c')];
        await showGroups(tester, library, [
          SimilarRecallGroup(
            prompts: [
              for (final card in cards.take(2))
                StudyPrompt(card: card, cue: StudyCue.fromAudio),
            ],
            comparisonCards: cards,
          ),
        ], format);
        await answerWord(tester);
        expect(library.saved.map((c) => c.id), [1]);
        await answerWord(tester, correct: false);
        expect(library.saved.map((c) => c.id), [1, 2]);
        expect(
          library.saved[0].reviewHistoryFor(StudyCue.fromAudio).single.rating,
          3,
        );
        expect(
          library.saved[1].reviewHistoryFor(StudyCue.fromAudio).single.rating,
          1,
        );
        expect(find.text('Compare words'), findsNothing);
        expect(find.text('Session complete'), findsOneWidget);
        expect(find.byKey(const ValueKey('group-recalled')), findsNothing);
        expect(find.text('GROUPS'), findsOneWidget);
        expect(find.text('Retry group'), findsNothing);
        expect(library.saved, hasLength(2));
        final recap = tester.widget<RecallRecapPage>(
          find.byType(RecallRecapPage),
        );
        expect(recap.reviewedCount, 2);
        expect(recap.missCount, 1);
        expect(recap.totalCount, 2);
      },
    );
  }
  testWidgets(
    'failed individual save retries once and another direction preserves history',
    (tester) async {
      final library = RecordingLibrary()..failId = 1;
      final card = soundCard(1, 'a');
      await showGroups(tester, library, [
        for (final cue in [StudyCue.fromLanguage, StudyCue.toLanguage])
          SimilarRecallGroup(
            prompts: [StudyPrompt(card: card, cue: cue)],
            comparisonCards: [card],
          ),
      ], GroupedRecallFormat.standard);
      await answerWord(tester);
      expect(library.saved, isEmpty);
      expect(find.text('Retry saving'), findsOneWidget);
      library.failId = null;
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect(library.saved, hasLength(1));
      expect(find.text('Next group'), findsNothing);
      expect(find.text('Session complete'), findsNothing);
      await answerWord(tester, correct: false);
      expect(library.saved, hasLength(2));
      expect(
        library.saved.last
            .reviewHistoryFor(StudyCue.fromLanguage)
            .single
            .rating,
        3,
      );
      expect(
        library.saved.last.reviewHistoryFor(StudyCue.toLanguage).single.rating,
        1,
      );
    },
  );
  testWidgets('ending after reveal does not grade an unanswered card', (
    tester,
  ) async {
    final library = RecordingLibrary();
    final cards = [soundCard(1, 'a'), soundCard(2, 'b')];
    await showGroups(tester, library, [
      SimilarRecallGroup(
        prompts: [
          for (final card in cards)
            StudyPrompt(card: card, cue: StudyCue.fromAudio),
        ],
        comparisonCards: cards,
      ),
    ], GroupedRecallFormat.standard);
    await answerWord(tester);
    await tester.tap(find.byKey(const ValueKey('group-question-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();
    expect(library.saved, hasLength(1));
    final recap = tester.widget<RecallRecapPage>(find.byType(RecallRecapPage));
    expect(recap.totalCount - recap.reviewedCount, 1);
  });
}
