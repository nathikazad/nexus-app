import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_page.dart';
import 'package:nx_cards/browser/language/language_page.dart';

void main() {
  testWidgets('home shows languages first and opens their category cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final dashboard = CardsDashboard(
      cards: [
        _word(
          id: 1,
          category: 'Script',
          learningStatus: LearningStatus.learning,
          schedule: const CardSchedule.initial(enabled: true),
        ),
        _word(
          id: 2,
          learningStatus: LearningStatus.learnt,
          schedule: const CardSchedule.initial(enabled: true),
        ),
        _word(
          id: 3,
          category: 'Adjective',
          learningStatus: LearningStatus.learning,
          schedule: const CardSchedule.initial(enabled: true),
        ),
        _word(
          id: 4,
          modelTypeName: 'Verb',
          learningStatus: LearningStatus.learning,
          schedule: const CardSchedule.initial(enabled: true),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardsDashboardProvider.overrideWith((_) => Stream.value(dashboard)),
        ],
        child: const MaterialApp(home: BrowserPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Languages'), findsOneWidget);
    expect(find.text('Malayalam'), findsOneWidget);
    expect(find.text('Script'), findsNothing);
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
    expect(find.byIcon(Icons.tune_outlined), findsOneWidget);
    await tester.tap(find.text('Malayalam'));
    await tester.pumpAndSettle();
    expect(find.text('Script'), findsOneWidget);
    expect(find.text('Noun'), findsOneWidget);
    expect(find.text('Adjective'), findsOneWidget);
    expect(find.text('Verb'), findsOneWidget);
    expect(find.byType(VerticalDivider), findsNWidgets(4));
    final nounTitle = tester.getCenter(find.text('Noun'));
    final nounDivider = tester.getCenter(
      find.byKey(const ValueKey('language-category-divider-Noun')),
    );
    expect(nounDivider.dx, greaterThan(nounTitle.dx));
    final nounLearnt = find.byKey(
      const ValueKey('language-category-noun-learnt'),
    );
    final nounLearning = find.byKey(
      const ValueKey('language-category-noun-learning'),
    );
    expect(find.descendant(of: nounLearnt, matching: find.text('1')), findsOne);
    expect(
      find.descendant(of: nounLearning, matching: find.text('0')),
      findsOne,
    );
    expect(
      tester.getCenter(nounLearnt).dx,
      lessThan(tester.getCenter(nounLearning).dx),
    );
    expect(
      find.byKey(const ValueKey('language-category-noun-remaining')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('language-category-noun-due')),
      findsOneWidget,
    );
    await tester.binding.setSurfaceSize(const Size(280, 844));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('language-category-noun-total')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('language-category-noun-learnt')),
      findsNothing,
    );
    await tester.binding.setSurfaceSize(const Size(1100, 844));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('language-category-noun-remaining')),
      findsOneWidget,
    );
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Library'), findsNothing);
    expect(find.text('Today'), findsNothing);
    expect(find.text('What are you learning?'), findsNothing);
    expect(find.text('Word categories'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home lists linked books below languages and opens all cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final dashboard = CardsDashboard(
      cards: [
        _word(
          id: 1,
          learningStatus: LearningStatus.learning,
          schedule: const CardSchedule.initial(enabled: true),
        ),
        _bookCard(2),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardsDashboardProvider.overrideWith((_) => Stream.value(dashboard)),
        ],
        child: const MaterialApp(home: BrowserPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Languages'), findsOneWidget);
    expect(find.text('Books'), findsOneWidget);
    expect(find.text('The Four Steps to the Epiphany'), findsOneWidget);
    await tester.tap(find.text('The Four Steps to the Epiphany'));
    await tester.pumpAndSettle();
    expect(find.text('Current  0'), findsOneWidget);
    expect(find.text('Past  0'), findsOneWidget);
    expect(find.text('Future  1'), findsOneWidget);
    await tester.tap(find.text('Future  1'));
    await tester.pumpAndSettle();
    expect(find.text('Why validate demand?'), findsOneWidget);
    expect(find.text('To avoid scaling an unproven model.'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('word-state-new')), findsNothing);
    expect(find.text('1 cards · 0 current'), findsOneWidget);

    await tester.tap(find.text('Study'));
    await tester.pumpAndSettle();
    expect(find.text('Study'), findsWidgets);
    expect(find.text('Recall'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('Recall percentage'), findsOneWidget);
    expect(find.text('How many cards?'), findsOneWidget);
    expect(find.text('What should be in front?'), findsNothing);
    await tester.tap(find.text('Recall'));
    await tester.pumpAndSettle();
    expect(find.text('Start recall'), findsOneWidget);
    expect(find.text('Recall percentage'), findsOneWidget);
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    expect(find.text('Start AI tutor'), findsOneWidget);
    expect(find.text('Recall percentage'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows front-to-back state and one due marker on current words', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final current = _word(
      id: 1,
      learningStatus: LearningStatus.learning,
      schedule: _schedule(now.subtract(const Duration(minutes: 2))),
    );
    final available = _word(
      id: 2,
      learningStatus: LearningStatus.notStarted,
      schedule: _schedule(now.subtract(const Duration(minutes: 2))),
    );
    final learnt = _word(
      id: 3,
      learningStatus: LearningStatus.learnt,
      schedule: _schedule(now.subtract(const Duration(minutes: 2))),
    );
    final dashboard = CardsDashboard(cards: [current, available, learnt]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith((_) => Stream.value(dashboard)),
        ],
        child: const MaterialApp(home: LanguageCategoryPage(category: 'Noun')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LEARNING  0%'), findsOneWidget);
    expect(find.text('DUE'), findsOneWidget);
    expect(find.byKey(const ValueKey('word-schedule-due')), findsOneWidget);
    expect(find.text('Current  1'), findsOneWidget);
    expect(find.text('Past  1'), findsOneWidget);
    expect(find.text('Future  1'), findsOneWidget);
    await tester.tap(find.text('Past  1'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('word-state-learning')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('right swipe moves learning and learnt words back one status', (
    tester,
  ) async {
    final repository = _RecordingCardLibrary();
    final now = DateTime.now().toUtc();
    final learning = _word(
      id: 1,
      learningStatus: LearningStatus.learning,
      schedule: _schedule(now),
    );
    final learnt = _word(
      id: 3,
      learningStatus: LearningStatus.learnt,
      schedule: _schedule(now),
    );
    final dashboard = CardsDashboard(cards: [learning, learnt]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardLibraryProvider.overrideWithValue(repository),
          cardsDashboardProvider.overrideWith((_) => Stream.value(dashboard)),
        ],
        child: const MaterialApp(home: LanguageCategoryPage(category: 'Noun')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('learning:1')),
      const Offset(100, 0),
    );
    await tester.pumpAndSettle();
    expect(repository.changes.last, (1, LearningStatus.notStarted));

    await tester.tap(find.text('Past  1'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('learnt:3')),
      const Offset(100, 0),
    );
    await tester.pumpAndSettle();
    expect(repository.changes.last, (3, LearningStatus.learning));
  });

  testWidgets('shows subtle state pills beside fronts and sorts by state', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final cards = [
      _word(
        id: 4,
        learningStatus: LearningStatus.learning,
        schedule: _stateSchedule(now, state: 'learning', isNew: true),
      ),
      _word(
        id: 3,
        learningStatus: LearningStatus.learning,
        schedule: _stateSchedule(now, state: 'review'),
        recallRatings: const [3, 3, 3, 3],
      ),
      _word(
        id: 5,
        learningStatus: LearningStatus.learning,
        schedule: _stateSchedule(now, state: 'review'),
        recallRatings: const [1, 1, 1, 3],
      ),
      _word(
        id: 2,
        learningStatus: LearningStatus.learning,
        schedule: _stateSchedule(now, state: 'relearning'),
      ),
      _word(
        id: 1,
        learningStatus: LearningStatus.learning,
        schedule: _stateSchedule(now, state: 'learning'),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(CardsDashboard(cards: cards)),
          ),
        ],
        child: const MaterialApp(home: LanguageCategoryPage(category: 'Noun')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LEARNING  0%'), findsOneWidget);
    expect(find.text('RELEARNING  0%'), findsOneWidget);
    expect(find.text('RETAINED  20%'), findsOneWidget);
    expect(find.text('RETAINED  80%'), findsOneWidget);
    expect(find.text('REVIEW'), findsNothing);
    expect(find.text('NEW'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('word-state-new')),
      findsOneWidget,
    );
    expect(
      (tester
                  .widget<Container>(
                    find.byKey(const ValueKey<String>('word-state-learning')),
                  )
                  .decoration
              as BoxDecoration)
          .color,
      const Color(0xfffff7ed),
    );
    expect(
      (tester
                  .widget<Container>(
                    find.byKey(const ValueKey<String>('word-state-relearning')),
                  )
                  .decoration
              as BoxDecoration)
          .color,
      const Color(0xfffff1f2),
    );
    expect(
      (tester
                  .widget<Container>(
                    find
                        .byKey(const ValueKey<String>('word-state-retained'))
                        .first,
                  )
                  .decoration
              as BoxDecoration)
          .color,
      const Color(0xffecfdf5),
    );
    expect(
      tester.getCenter(find.text('word 1')).dx,
      lessThan(tester.getCenter(find.text('LEARNING  0%')).dx),
    );
    final stateOrder = [
      'word 1',
      'word 2',
      'word 5',
      'word 3',
      'word 4',
    ].map((label) => tester.getCenter(find.text(label)).dy).toList();
    expect(stateOrder, orderedEquals([...stateOrder]..sort()));
  });
}

final class _RecordingCardLibrary implements CardLibrary {
  final changes = <(int, LearningStatus)>[];

  @override
  Future<void> setLearningStatus(StudyCard card, LearningStatus status) async {
    changes.add((card.id, status));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StudyCard _word({
  required int id,
  required LearningStatus learningStatus,
  required CardSchedule schedule,
  String category = 'Noun',
  String? modelTypeName,
  List<int> recallRatings = const <int>[],
}) => StudyCard(
  id: id,
  content: LanguageCardContent(
    english: 'word $id',
    originalScript: id == 1 ? 'ആശങ്ക' : 'ഉത്തരവാദിത്വം',
    transliteration: id == 1 ? 'aashanka' : 'utharavaadithvam',
  ),
  schedules: {
    StudyCue.fromLanguage: schedule,
    StudyCue.toLanguage: const CardSchedule.initial(enabled: true),
    StudyCue.transliteration: const CardSchedule.initial(enabled: true),
  },
  reviewHistory: <StudyCue, List<CardReview>>{
    if (recallRatings.isNotEmpty)
      StudyCue.fromLanguage: [
        for (var index = 0; index < recallRatings.length; index++)
          CardReview(
            id: 'review-$id-$index',
            reviewedAt: DateTime.utc(2026, 8, index + 1),
            rating: recallRatings[index],
            elapsedSeconds: 86400,
            scheduledSeconds: 86400,
          ),
      ],
  },
  suspended: false,
  learningStatus: learningStatus,
  tags: category == 'Script'
      ? const <String, List<String>>{
          'Language': ['Malayalam'],
        }
      : <String, List<String>>{
          'Language': ['Malayalam'],
          'Word Category': [category],
        },
  modelTypeName: modelTypeName ?? (category == 'Script' ? 'Script' : 'Word'),
);

StudyCard _bookCard(int id) => StudyCard(
  id: id,
  content: const BasicCardContent(
    front: 'Why validate demand?',
    back: 'To avoid scaling an unproven model.',
  ),
  schedules: const {StudyCue.fromLanguage: CardSchedule.initial(enabled: true)},
  reviewHistory: const {},
  suspended: false,
  sourceBookId: 4195,
  sourceBookName: 'The Four Steps to the Epiphany',
  modelTypeName: 'Flashcard',
);

CardSchedule _schedule(DateTime dueAt) => CardSchedule(
  enabled: true,
  dueAt: dueAt,
  lastReviewedAt: dueAt.subtract(const Duration(days: 1)),
  stability: 1,
  difficulty: 5,
  schedulingState: 'learning',
  learningStep: 0,
  reviewCount: 1,
  lapseCount: 0,
);

CardSchedule _stateSchedule(
  DateTime now, {
  required String state,
  bool isNew = false,
}) => CardSchedule(
  enabled: true,
  dueAt: now.add(const Duration(days: 1)),
  lastReviewedAt: isNew ? null : now.subtract(const Duration(days: 1)),
  stability: isNew ? null : 1,
  difficulty: isNew ? null : 5,
  schedulingState: state,
  learningStep: state == 'review' ? null : 0,
  reviewCount: isNew ? 0 : 1,
  lapseCount: 0,
);
