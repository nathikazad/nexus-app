import 'package:nx_cards/browser/card_list/current_cards_tab.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';
import 'package:nx_cards/scheduling/study_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_error.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/card_list/card_schedule_status.dart';
import 'package:nx_cards/browser/card_list/learning_cards.dart';
import 'package:nx_cards/browser/card_list/study_launcher.dart';
import 'package:nx_cards/scheduling/review_progression.dart';
import 'package:nx_cards/study/study_setup_page.dart';

class BookPage extends ConsumerWidget {
  const BookPage({super.key, required this.bookId, required this.bookName});

  final int bookId;
  final String bookName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(
      cardsCollectionProvider((language: null, bookId: bookId)),
    );
    final historyWindow =
        ref.watch(reviewProgressionSettingsProvider).value?.historyWindow ?? 10;
    return Scaffold(
      appBar: AppBar(title: Text(bookName)),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => BrowserLoadError(
          error: error,
          onRetry: () => ref.read(cardsInvalidationProvider)(),
        ),
        data: (data) {
          final cards = data.cardsForBook(bookId);
          final upcoming = cards
              .where(
                (c) =>
                    learningStage(
                      c,
                      StudyCue.fromLanguage,
                      window: historyWindow,
                    ) ==
                    LearningStage.upcoming,
              )
              .toList();
          final now = DateTime.now().toUtc();
          final learning = sortCardsByScheduleState(
            cards.where(
              (card) =>
                  learningStage(
                    card,
                    StudyCue.fromLanguage,
                    window: historyWindow,
                  ) ==
                  LearningStage.current,
            ),
            now,
            historyWindow: historyWindow,
          );
          final learnt = sortCardsByScheduleState(
            cards.where(
              (card) =>
                  learningStage(
                    card,
                    StudyCue.fromLanguage,
                    window: historyWindow,
                  ) ==
                  LearningStage.past,
            ),
            now,
            historyWindow: historyWindow,
          );
          final notStarted = sortCardsByScheduleState(
            cards.where((card) => card.learningStatus == LearningStatus.future),
            now,
            historyWindow: historyWindow,
          );
          return DefaultTabController(
            length: 3,
            initialIndex: 0,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${cards.length} cards · ${learning.length + learnt.length} current',
                              style: const TextStyle(color: RecallColors.muted),
                            ),
                          ),
                          StudyLauncher(
                            followLearningTab: true,
                            studyScope: StudyScope(bookId: bookId),
                            title: bookName,
                            preferenceKey: 'book:$bookId',
                            prompts: [
                              for (final card in cards)
                                StudyPrompt(
                                  card: card,
                                  cue: StudyCue.fromLanguage,
                                ),
                            ],
                            studyCards: cards,
                            sourceKind: StudySourceKind.book,
                            builder: (onPressed) => FilledButton(
                              onPressed: onPressed,
                              child: const Text('Study'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        Tab(
                          text: 'Current  ${learning.length + learnt.length}',
                        ),
                        Tab(text: 'Upcoming  ${upcoming.length}'),
                        Tab(text: 'Backlog  ${notStarted.length}'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      CurrentCardsTab(
                        cards: [...learning, ...learnt],
                        dashboard: data,
                      ),
                      LearningCardsTab(
                        cards: upcoming,
                        nextStatus: LearningStatus.recall,
                        actionLabel: 'Activate',
                        emptyText: 'Move Backlog cards here to practice.',
                        dashboard: data,
                      ),
                      LearningCardsTab(
                        cards: notStarted,
                        emptyText: 'Every card has been started.',
                        nextStatus: LearningStatus.practice,
                        actionLabel: '+',
                        dashboard: data,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
