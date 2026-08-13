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
    final dashboard = ref.watch(cardsDashboardProvider);
    final historyWindow =
        ref.watch(reviewProgressionSettingsProvider).value?.historyWindow ?? 5;
    return Scaffold(
      appBar: AppBar(title: Text(bookName)),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => BrowserLoadError(
          error: error,
          onRetry: () => ref.invalidate(cardsDashboardProvider),
        ),
        data: (data) {
          final cards = data.cardsForBook(bookId);
          final now = DateTime.now().toUtc();
          final learning = sortCardsByScheduleState(
            cards.where(
              (card) => card.learningStatus == LearningStatus.learning,
            ),
            now,
            historyWindow: historyWindow,
          );
          final learnt = sortCardsByScheduleState(
            cards.where((card) => card.learningStatus == LearningStatus.learnt),
            now,
            historyWindow: historyWindow,
          );
          final notStarted = sortCardsByScheduleState(
            cards.where(
              (card) => card.learningStatus == LearningStatus.notStarted,
            ),
            now,
            historyWindow: historyWindow,
          );
          return DefaultTabController(
            length: LearningStatus.values.length,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${cards.length} cards · ${learning.length} current',
                              style: const TextStyle(color: RecallColors.muted),
                            ),
                          ),
                          StudyLauncher(
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
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        Tab(text: 'Current  ${learning.length}'),
                        Tab(text: 'Past  ${learnt.length}'),
                        Tab(text: 'Future  ${notStarted.length}'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      LearningCardsTab(
                        cards: learning,
                        showScheduleStatus: true,
                        emptyText: 'No cards are currently being learned.',
                        previousStatus: LearningStatus.notStarted,
                        previousActionLabel: '←',
                        nextStatus: LearningStatus.learnt,
                        actionLabel: '✓',
                        dashboard: data,
                      ),
                      LearningCardsTab(
                        cards: learnt,
                        emptyText: 'No cards have been moved to Past yet.',
                        previousStatus: LearningStatus.learning,
                        previousActionLabel: '←',
                        dashboard: data,
                      ),
                      LearningCardsTab(
                        cards: notStarted,
                        emptyText: 'Every card has been started.',
                        nextStatus: LearningStatus.learning,
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
