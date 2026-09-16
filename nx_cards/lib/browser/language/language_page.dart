import 'package:nx_cards/app/adaptive_card_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_error.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/card_list/card_schedule_status.dart';
import 'package:nx_cards/browser/card_list/learning_cards.dart';
import 'package:nx_cards/browser/card_list/card_search.dart';
import 'package:nx_cards/browser/card_list/study_launcher.dart';
import 'package:nx_cards/browser/language/language_category_order.dart';
import 'package:nx_cards/scheduling/review_progression.dart';

class LanguagePage extends ConsumerWidget {
  const LanguagePage({super.key, required this.language});

  final String language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(
      cardsCollectionProvider((language: language, bookId: null)),
    );
    return Scaffold(
      appBar: AppBar(title: Text(language)),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => BrowserLoadError(
          error: error,
          onRetry: () => ref.read(cardsInvalidationProvider)(),
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
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdaptiveCardGrid(
                    children: [
                      _LanguageCategoryCard(
                        category: 'All',
                        allCards: true,
                        data: data,
                        language: language,
                      ),
                      for (final category in categories)
                        _LanguageCategoryCard(
                          category: category,
                          data: data,
                          language: language,
                        ),
                    ],
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
    this.allCards = false,
  });

  final String category;
  final bool allCards;
  final CardsDashboard data;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final cards = data.cards
        .where(
          (card) =>
              (allCards || card.belongsToStudyCategory(category)) &&
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
      studyCategory: allCards ? null : category,
      language: language,
      cue: StudyCue.fromLanguage,
    );
    final labelStyle = TextStyle(
      fontSize: 10,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final valueStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurface,
    );
    double textWidth(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final width = painter.width.ceilToDouble();
      painter.dispose();
      return width;
    }

    final metrics = <(int, String)>[
      (cards.length, 'Total'),
      if (!allCards) (learnt, 'Learnt'),
      (current, 'Learning'),
      (due, 'Due'),
      if (!allCards) (remaining, 'Remaining'),
    ];
    final widths = metrics.map((entry) {
      final labelWidth = textWidth(entry.$2, labelStyle);
      final valueWidth = textWidth('${entry.$1}', valueStyle);
      return (labelWidth > valueWidth ? labelWidth : valueWidth) + 8;
    }).toList();
    Widget metric(int value, String label, double width) => SizedBox(
      key: ValueKey(
        'language-category-${category.toLowerCase()}-${label.toLowerCase()}',
      ),
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', maxLines: 1, softWrap: false, style: valueStyle),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, softWrap: false, style: labelStyle),
        ],
      ),
    );
    return Card(
      color: allCards
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LanguageCategoryPage(
              category: category,
              language: language,
              allCards: allCards,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final metricWidgets = [
                for (var i = 0; i < metrics.length; i++)
                  metric(metrics[i].$1, metrics[i].$2, widths[i]),
              ];
              final statsWidth =
                  widths.fold<double>(0, (a, b) => a + b) +
                  (metrics.length - 1) * 8;
              final inline = constraints.maxWidth >= 160 + statsWidth;
              final identity = Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Icon(
                            categoryIcon(category),
                            size: 20,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: allCards
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final stats = Wrap(
                spacing: 8,
                runSpacing: 12,
                children: metricWidgets,
              );
              if (!inline) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [identity, const SizedBox(height: 16), stats],
                );
              }
              return Row(
                children: [
                  Expanded(child: identity),
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
                  SizedBox(width: statsWidth, child: stats),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class LanguageCategoryPage extends ConsumerStatefulWidget {
  const LanguageCategoryPage({
    super.key,
    required this.category,
    this.language,
    this.allCards = false,
  });

  final String category;
  final bool allCards;
  final String? language;

  @override
  ConsumerState<LanguageCategoryPage> createState() =>
      _LanguageCategoryPageState();
}

class _LanguageCategoryPageState extends ConsumerState<LanguageCategoryPage> {
  final _searchController = TextEditingController();
  bool _searching = false;
  String get category => widget.category;
  String? get language => widget.language;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _closeSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = false;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(
      cardsCollectionProvider((language: language, bookId: null)),
    );
    final historyWindow =
        ref.watch(reviewProgressionSettingsProvider).value?.historyWindow ?? 5;
    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => BrowserLoadError(
          error: error,
          onRetry: () => ref.read(cardsInvalidationProvider)(),
        ),
        data: (data) {
          final cards = data.cards
              .where(
                (card) =>
                    (widget.allCards ||
                        card.belongsToStudyCategory(category)) &&
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
          if (category == 'Phrase') {
            final pastWordIds = <int>{
              for (final card in data.cards)
                if (card.isWordCard &&
                    card.learningStatus == LearningStatus.learnt)
                  card.id,
            };
            final existingOrder = <int, int>{
              for (final (index, card) in notStarted.indexed) card.id: index,
            };
            int pastLinkCount(StudyCard card) =>
                card.linkedWordIds.intersection(pastWordIds).length;
            notStarted.sort((left, right) {
              final byPastLinks = pastLinkCount(
                right,
              ).compareTo(pastLinkCount(left));
              return byPastLinks != 0
                  ? byPastLinks
                  : existingOrder[left.id]!.compareTo(existingOrder[right.id]!);
            });
          }
          final queue = data.studyQueue(
            DateTime.now(),
            studyCategory: widget.allCards ? null : category,
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
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${cards.length} ${widget.allCards
                                  ? 'cards'
                                  : category == 'Script'
                                  ? 'letters'
                                  : 'words'} · ${learning.length} learning',
                              style: const TextStyle(color: RecallColors.muted),
                            ),
                          ),
                          StudyLauncher(
                            title: language == null
                                ? category
                                : '$language · $category',
                            preferenceKey:
                                'language-category:${language ?? 'all'}:${widget.allCards ? '*all*' : category}',
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
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: _searching
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              key: const ValueKey('card-search-field'),
                              controller: _searchController,
                              autofocus: true,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Search all cards in $category',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: IconButton(
                                  tooltip: 'Close search',
                                  onPressed: _closeSearch,
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: TabBar(
                                  isScrollable: false,
                                  labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  tabAlignment: TabAlignment.fill,
                                  labelStyle: const TextStyle(fontSize: 12),
                                  tabs: [
                                    Tab(text: 'Current  ${learning.length}'),
                                    Tab(text: 'Past  ${learnt.length}'),
                                    Tab(text: 'Future  ${notStarted.length}'),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Search all cards',
                                onPressed: () =>
                                    setState(() => _searching = true),
                                icon: const Icon(Icons.search),
                              ),
                            ],
                          ),
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _searching ? 1 : 0,
                    children: [
                      TabBarView(
                        children: [
                          LearningCardsTab(
                            cards: learning,
                            showScheduleStatus: true,
                            emptyText: category == 'Script'
                                ? 'No letters are currently being learned.'
                                : widget.allCards
                                ? 'No cards are currently being learned.'
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
                                : widget.allCards
                                ? 'No cards have been marked learnt yet.'
                                : 'No words have been marked learnt yet.',
                            previousStatus: LearningStatus.learning,
                            previousActionLabel: '←',
                            dashboard: data,
                          ),
                          LearningCardsTab(
                            cards: notStarted,
                            emptyText: category == 'Script'
                                ? 'Every letter has been started.'
                                : widget.allCards
                                ? 'Every card has been started.'
                                : 'Every word has been started.',
                            nextStatus: LearningStatus.learning,
                            actionLabel: '+',
                            dashboard: data,
                          ),
                        ],
                      ),
                      if (_searching)
                        LearningCardsTab(
                          key: const ValueKey('card-search-results'),
                          cards: cards
                              .where(
                                (card) => cardMatchesSearch(
                                  card,
                                  _searchController.text,
                                ),
                              )
                              .toList(growable: false),
                          emptyText: 'No matching cards.',
                          dashboard: data,
                          showLearningStatus: true,
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
