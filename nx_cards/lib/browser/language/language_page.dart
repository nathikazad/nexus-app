import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_error.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/card_list/card_schedule_status.dart';
import 'package:nx_cards/browser/card_list/learning_cards.dart';
import 'package:nx_cards/browser/card_list/study_launcher.dart';
import 'package:nx_cards/browser/language/language_category_order.dart';
import 'package:nx_cards/scheduling/review_progression.dart';

class LanguagePage extends ConsumerWidget {
  const LanguagePage({super.key, required this.language});

  final String language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(cardsDashboardProvider);
    return Scaffold(
      appBar: AppBar(title: Text(language)),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => BrowserLoadError(
          error: error,
          onRetry: () => ref.invalidate(cardsDashboardProvider),
        ),
        data: (data) =>
            _LanguageCategoriesDashboard(data: data, language: language),
      ),
    );
  }
}

class _LanguageCategoriesDashboard extends ConsumerWidget {
  const _LanguageCategoriesDashboard({required this.data, this.language});

  final CardsDashboard data;
  final String? language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceCards = language == null
        ? data.cards
        : data.cardsForLanguage(language!);
    final categories = orderedLanguageCategories(
      sourceCards.expand((card) => card.studyCategories),
    );
    return RefreshIndicator(
      onRefresh: ref.read(cardsLibrarySyncProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth >= 720
                          ? (constraints.maxWidth - 14) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          for (final category in categories)
                            SizedBox(
                              width: width,
                              child: _LanguageCategoryCard(
                                category: category,
                                data: data,
                                language: language,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCategoryCard extends StatelessWidget {
  const _LanguageCategoryCard({
    required this.category,
    required this.data,
    this.language,
  });

  final String category;
  final CardsDashboard data;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final cards = data.cards
        .where(
          (card) =>
              card.belongsToStudyCategory(category) &&
              (language == null || data.languageFor(card) == language),
        )
        .toList(growable: false);
    final current = cards
        .where((card) => card.learningStatus == LearningStatus.learning)
        .length;
    final learnt = cards
        .where((card) => card.learningStatus == LearningStatus.learnt)
        .length;
    final remaining = cards
        .where((card) => card.learningStatus == LearningStatus.notStarted)
        .length;
    final due = data.dueCount(
      DateTime.now(),
      studyCategory: category,
      language: language,
      cue: StudyCue.fromLanguage,
    );
    Widget metric(int value, String label, double width) => SizedBox(
      key: ValueKey(
        'language-category-${category.toLowerCase()}-${label.toLowerCase()}',
      ),
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: RecallColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: RecallColors.faint),
          ),
        ],
      ),
    );
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                LanguageCategoryPage(category: category, language: language),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Reserve a readable icon/title area, then admit metrics from
              // left to right. As space shrinks, the rightmost metric drops.
              const identityAndDividerWidth = 135.0;
              final metricWidth =
                  constraints.maxWidth - identityAndDividerWidth;
              final showLearnt = metricWidth >= 76;
              final showLearning = metricWidth >= 126;
              final showDue = metricWidth >= 160;
              final showRemaining = metricWidth >= 212;
              return Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: RecallColors.soft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: RecallColors.line),
                          ),
                          child: Icon(
                            categoryIcon(category),
                            size: 20,
                            color: RecallColors.ink,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 44,
                    child: VerticalDivider(
                      key: ValueKey('language-category-divider-$category'),
                      width: 1,
                      thickness: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  metric(cards.length, 'Total', 34),
                  if (showLearnt) ...[
                    const SizedBox(width: 4),
                    metric(learnt, 'Learnt', 38),
                  ],
                  if (showLearning) ...[
                    const SizedBox(width: 4),
                    metric(current, 'Learning', 46),
                  ],
                  if (showDue) ...[
                    const SizedBox(width: 4),
                    metric(due, 'Due', 30),
                  ],
                  if (showRemaining) ...[
                    const SizedBox(width: 4),
                    metric(remaining, 'Remaining', 48),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class LanguageCategoryPage extends ConsumerWidget {
  const LanguageCategoryPage({
    super.key,
    required this.category,
    this.language,
  });

  final String category;
  final String? language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(cardsDashboardProvider);
    final historyWindow =
        ref.watch(reviewProgressionSettingsProvider).value?.historyWindow ?? 5;
    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => BrowserLoadError(
          error: error,
          onRetry: () => ref.invalidate(cardsDashboardProvider),
        ),
        data: (data) {
          final cards = data.cards
              .where(
                (card) =>
                    card.belongsToStudyCategory(category) &&
                    (language == null || data.languageFor(card) == language),
              )
              .toList(growable: false);
          final now = DateTime.now().toUtc();
          final learning = sortWordsByScheduleState(
            cards.where(
              (card) => card.learningStatus == LearningStatus.learning,
            ),
            now,
            historyWindow: historyWindow,
          );
          final learnt = sortWordsByScheduleState(
            cards.where((card) => card.learningStatus == LearningStatus.learnt),
            now,
            historyWindow: historyWindow,
          );
          final notStarted = sortWordsByScheduleState(
            cards.where(
              (card) => card.learningStatus == LearningStatus.notStarted,
            ),
            now,
            historyWindow: historyWindow,
          );
          final queue = data.studyQueue(
            DateTime.now(),
            studyCategory: category,
            language: language,
            newCardLimit:
                (learning.length + learnt.length) * StudyCue.values.length,
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
                              '${cards.length} ${category == 'Script' ? 'letters' : 'words'} · ${learning.length} learning',
                              style: const TextStyle(color: RecallColors.muted),
                            ),
                          ),
                          StudyLauncher(
                            title: language == null
                                ? category
                                : '$language · $category',
                            preferenceKey:
                                'language-category:${language ?? 'all'}:$category',
                            prompts: queue,
                            studyCards: [...learning, ...learnt],
                            languagePair: language == null
                                ? languagesForCards(data, cards)
                                : LanguagePair('Front', language!),
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
                        emptyText: category == 'Script'
                            ? 'No letters are currently being learned.'
                            : 'No words are currently being learned.',
                        previousStatus: LearningStatus.notStarted,
                        previousActionLabel: '←',
                        nextStatus: LearningStatus.learnt,
                        actionLabel: '✓',
                        dashboard: data,
                      ),
                      LearningCardsTab(
                        cards: learnt,
                        emptyText: category == 'Script'
                            ? 'No letters have been marked learnt yet.'
                            : 'No words have been marked learnt yet.',
                        previousStatus: LearningStatus.learning,
                        previousActionLabel: '←',
                        dashboard: data,
                      ),
                      LearningCardsTab(
                        cards: notStarted,
                        emptyText: category == 'Script'
                            ? 'Every letter has been started.'
                            : 'Every word has been started.',
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

IconData categoryIcon(String category) => switch (category) {
  'Noun' => Icons.inventory_2_outlined,
  'Verb' => Icons.directions_run_outlined,
  'Adjective' => Icons.tune_outlined,
  'Adverb' => Icons.speed_outlined,
  'Postposition' => Icons.alt_route_outlined,
  'Script' => Icons.gesture_outlined,
  _ => Icons.text_fields_outlined,
};
