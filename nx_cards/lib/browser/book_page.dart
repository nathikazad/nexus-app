import 'package:nx_cards/goals/daily_goal.dart';
import 'package:nx_cards/browser/card_list/practice_selection_page.dart';
import 'package:nx_cards/browser/card_list/backlog_page.dart';
import 'package:nx_cards/browser/card_list/current_cards_tab.dart';
import 'package:nx_cards/scheduling/study_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_error.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/card_list/study_launcher.dart';
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
          final current = cards
              .where((c) => c.learningStatus == LearningStatus.recall)
              .toList();
          return PracticeSelectionScope(
            title: bookName,
            cards: current,
            languagePair: null,
            sourceKind: StudySourceKind.book,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: DailyGoalBar(name: bookName, bookId: bookId),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                  child: LibraryActions(
                    practice: const PracticeSelectionButton(),
                    add: LibraryActionButton(
                      key: const ValueKey('open-backlog'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BacklogPage(
                            title: bookName,
                            bookId: bookId,
                            matches: (card) => card.sourceBookId == bookId,
                          ),
                        ),
                      ),
                      icon: Icons.add,
                      label: 'Add',
                    ),
                    recall: StudyLauncher(
                      followPracticeSelection: true,
                      studyScope: StudyScope(bookId: bookId),
                      title: bookName,
                      preferenceKey: 'book:$bookId',
                      prompts: [
                        for (final card in current)
                          StudyPrompt(card: card, cue: StudyCue.frontToBack),
                      ],
                      studyCards: current,
                      sourceKind: StudySourceKind.book,
                      builder: (onPressed) => LibraryActionButton(
                        filled: true,
                        onPressed: onPressed,
                        icon: Icons.replay_rounded,
                        label: 'Recall',
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: CurrentCardsTab(cards: current, dashboard: data),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
