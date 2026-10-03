import 'package:nx_cards/scheduling/review_progression.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/browser_error.dart';
import 'package:nx_cards/scheduling/future_card_rank.dart';
import 'bulk_card_selection.dart';
import 'learning_cards.dart';

class BacklogPage extends ConsumerWidget {
  const BacklogPage({
    super.key,
    required this.title,
    required this.matches,
    this.language,
    this.bookId,
  });
  final String title;
  final bool Function(StudyCard) matches;
  final String? language;
  final int? bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      cardsCollectionProvider((language: language, bookId: bookId)),
    );
    return Scaffold(
      appBar: AppBar(title: Text('$title · Backlog')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => BrowserLoadError(
          error: error,
          onRetry: () => ref.read(cardsInvalidationProvider)(),
        ),
        data: (dashboard) {
          final scores = futureCardScores(
            dashboard.cards,
            cue: null,
            historyWindow:
                ref
                    .watch(reviewProgressionSettingsProvider)
                    .value
                    ?.historyWindow ??
                10,
          );
          final cards = sortFutureCards(
            dashboard.cards.where(
              (c) => matches(c) && c.learningStatus == LearningStatus.future,
            ),
            scores,
          );
          return BulkCardSelectionScope(
            backlogOnly: true,
            cards: cards,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    children: [const Spacer(), const BulkSelectButton()],
                  ),
                ),
                Expanded(
                  child: LearningCardsTab(
                    cards: cards,
                    dashboard: dashboard,
                    priorityScores: scores,
                    emptyText: 'No cards in Backlog.',
                    nextStatus: LearningStatus.recall,
                    actionLabel: '+',
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
