import 'package:nx_cards/scheduling/future_card_rank.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';
import 'package:nx_cards/scheduling/language_direction.dart';
import 'package:nx_cards/scheduling/study_scope.dart';
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
import 'package:nx_cards/browser/language/language_groups.dart';
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
      appBar: AppBar(
        title: Text(language),
        actions: [
          IconButton(
            tooltip: 'All cards',
            icon: const Icon(Icons.view_list_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LanguageCategoryPage(
                  category: 'All',
                  allCards: true,
                  language: language,
                ),
              ),
            ),
          ),
          LanguageDirectionButton(language: language),
        ],
      ),
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
    final groups = languageGroups(sourceCards);
    final collections = languageGroups(sourceCards, tagSystem: 'Collection');
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Categories',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LanguageCategoryCard(
                        key: const ValueKey('language-all-cards'),
                        category: 'All',
                        allCards: true,
                        data: data,
                        language: language,
                      ),
                      for (final group in groups)
                        _LanguageCategoryCard(
                          key: ValueKey((
                            group.tagSystem,
                            group.path?.join('/') ?? group.name,
                          )),
                          category: group.name,
                          categoryPath: group.path,
                          tagSystem: group.tagSystem,
                          disambiguate:
                              groups.where((g) => g.name == group.name).length >
                              1,
                          data: data,
                          language: language,
                        ),
                    ],
                  ),
                  if (collections.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Collections',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final group in collections)
                          _LanguageCategoryCard(
                            key: ValueKey((
                              group.tagSystem,
                              group.path?.join('/') ?? group.name,
                            )),
                            category: group.name,
                            categoryPath: group.path,
                            tagSystem: 'Collection',
                            data: data,
                            language: language,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCategoryCard extends ConsumerStatefulWidget {
  const _LanguageCategoryCard({
    super.key,
    required this.category,
    required this.data,
    this.language,
    this.tagSystem,
    this.categoryPath,
    this.disambiguate = false,
    this.allCards = false,
  });

  final bool allCards;
  final String category;
  final String? tagSystem;
  final List<String>? categoryPath;
  final bool disambiguate;
  final CardsDashboard data;
  final String? language;

  @override
  ConsumerState<_LanguageCategoryCard> createState() =>
      _LanguageCategoryCardState();
}

class _LanguageCategoryCardState extends ConsumerState<_LanguageCategoryCard> {
  bool expanded = false;
  bool get allCards => widget.allCards;
  String get category => widget.category;
  String? get tagSystem => widget.tagSystem;
  bool get disambiguate => widget.disambiguate;
  CardsDashboard get data => widget.data;
  String? get language => widget.language;

  @override
  Widget build(BuildContext context) {
    final cards = data.cards
        .where(
          (card) =>
              (allCards ||
                  LanguageGroup(
                    category,
                    tagSystem: tagSystem,
                    path: widget.categoryPath,
                  ).contains(card)) &&
              (language == null || data.languageFor(card) == language),
        )
        .toList(growable: false);
    final children = allCards || tagSystem == 'Collection'
        ? <LanguageGroup>[]
        : languageGroups(cards, parent: widget.categoryPath ?? [category]);
    final cue = ref.watch(languageDirectionProvider(language));
    final window =
        ref.watch(reviewProgressionSettingsProvider).value?.historyWindow ?? 10;
    int count(LearningStage stage) => cards
        .where((card) => learningStage(card, cue, window: window) == stage)
        .length;
    final current = count(LearningStage.current);
    final upcoming = count(LearningStage.upcoming);
    final learnt = count(LearningStage.past);
    final remaining = count(LearningStage.future);
    final due = cards
        .where(
          (card) =>
              learningStage(card, cue, window: window) == LearningStage.past &&
              !card.suspended &&
              card.scheduleFor(cue).isDueAt(DateTime.now()),
        )
        .length;
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
      (current, 'Current'),
      (due, 'Due'),
      (upcoming, 'Practice'),
      (learnt, 'Past'),
      (remaining, 'Future'),
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
    final tile = Card(
      color: allCards
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LanguageCategoryPage(
              category: category,
              allCards: allCards,
              categoryPath: widget.categoryPath,
              language: language,
              tagSystem: tagSystem,
              disambiguate: disambiguate,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final title = disambiguate
                  ? '$category (${tagSystem ?? 'Type'})'
                  : category == 'Word'
                  ? 'Words'
                  : category == 'Phrase'
                  ? 'Phrases'
                  : category;
              const titleStyle = TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              );
              final controlsWidth = children.isEmpty ? 0.0 : 48.0;
              final titleBudget =
                  (constraints.maxWidth -
                          controlsWidth -
                          49 -
                          12 -
                          widths.first)
                      .clamp(32.0, 180.0);
              final titleWidth = textWidth(
                title,
                titleStyle,
              ).clamp(32.0, titleBudget);
              final identityWidth = titleWidth + controlsWidth + 49;
              // Add counts in priority order only while their measured text fits.
              // Keep a readable title and all navigation controls at every width.
              final budget = constraints.maxWidth - identityWidth - 12;
              var statsWidth = 0.0;
              var visibleCount = 0;
              for (final width in widths) {
                final nextWidth =
                    statsWidth + (visibleCount == 0 ? 0 : 8) + width;
                if (nextWidth > budget) break;
                statsWidth = nextWidth;
                visibleCount++;
              }
              final metricWidgets = <Widget>[
                for (var i = 0; i < visibleCount; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  metric(metrics[i].$1, metrics[i].$2, widths[i]),
                ],
              ];
              final identity = Row(
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
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Icon(
                      tagSystem == 'Collection'
                          ? Icons.collections_bookmark_outlined
                          : categoryIcon(category),
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                  if (children.isNotEmpty)
                    IconButton(
                      key: ValueKey('expand-category-$category'),
                      tooltip: expanded
                          ? 'Hide subcategories'
                          : 'Show subcategories',
                      onPressed: () => setState(() => expanded = !expanded),
                      icon: Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                      ),
                    ),
                ],
              );
              return Row(
                children: [
                  Expanded(child: identity),
                  if (visibleCount > 0) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: statsWidth,
                      child: Row(children: metricWidgets),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile,
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              children: [
                for (final child in children)
                  _LanguageCategoryCard(
                    key: ValueKey(child.path?.join('/') ?? child.name),
                    category: child.name,
                    categoryPath: child.path,
                    tagSystem: child.tagSystem,
                    data: data,
                    language: language,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class LanguageCategoryPage extends ConsumerStatefulWidget {
  const LanguageCategoryPage({
    super.key,
    required this.category,
    this.language,
    this.allCards = false,
    this.tagSystem,
    this.categoryPath,
    this.disambiguate = false,
  });

  final String category;
  final bool allCards;
  final String? tagSystem;
  final List<String>? categoryPath;
  final bool disambiguate;
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
        ref.watch(reviewProgressionSettingsProvider).value?.historyWindow ?? 10;
    final cue = ref.watch(languageDirectionProvider(language));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.disambiguate
              ? '$category (${widget.tagSystem ?? 'Type'})'
              : category,
        ),
      ),
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
                        LanguageGroup(
                          category,
                          tagSystem: widget.tagSystem,
                          path: widget.categoryPath,
                        ).contains(card)) &&
                    (language == null || data.languageFor(card) == language),
              )
              .toList(growable: false);
          final now = DateTime.now().toUtc();
          final upcoming = cards
              .where(
                (card) =>
                    learningStage(card, cue, window: historyWindow) ==
                    LearningStage.upcoming,
              )
              .toList();
          final learning = sortWordsByScheduleState(
            cards.where(
              (card) =>
                  learningStage(card, cue, window: historyWindow) ==
                  LearningStage.current,
            ),
            now,
            historyWindow: historyWindow,
            cue: cue,
          );
          final learnt = sortWordsByScheduleState(
            cards.where(
              (card) =>
                  learningStage(card, cue, window: historyWindow) ==
                  LearningStage.past,
            ),
            now,
            historyWindow: historyWindow,
            cue: cue,
          );
          final futureScores = futureCardScores(
            data.cards,
            cue: cue,
            historyWindow: historyWindow,
          );
          final notStarted = sortFutureCards(
            cards.where(
              (card) => card.learningStatus == LearningStatus.inactive,
            ),
            futureScores,
          );
          final queue = [
            for (final card in cards.where((c) => c.active)) ...card.prompts,
          ];
          return DefaultTabController(
            length: LearningStage.values.length,
            initialIndex: learning.isNotEmpty ? 1 : 0,
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
                              '${cards.length} ${widget.allCards || widget.tagSystem != null
                                  ? 'cards'
                                  : category == 'Script'
                                  ? 'letters'
                                  : 'words'} · ${learning.length} learning',
                              style: const TextStyle(color: RecallColors.muted),
                            ),
                          ),
                          StudyLauncher(
                            followLearningTab: true,
                            studyScope: StudyScope(
                              language: language,
                              tagSystem: widget.tagSystem ?? 'Category',
                              categoryPath: widget.categoryPath,
                              tag: widget.allCards ? null : category,
                            ),
                            title: language == null
                                ? category
                                : '$language · $category',
                            preferenceKey: widget.tagSystem == null
                                ? 'language-category:${language ?? 'all'}:${widget.allCards ? '*all*' : category}'
                                : 'language-tag:${Uri.encodeComponent(language ?? 'all')}:${Uri.encodeComponent(widget.tagSystem!)}:${Uri.encodeComponent(widget.categoryPath?.join('/') ?? category)}',
                            prompts: queue,
                            studyCards: [...upcoming, ...learning, ...learnt],
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
                                  isScrollable: true,
                                  labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  tabAlignment: TabAlignment.start,
                                  labelStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  unselectedLabelStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  tabs: [
                                    Tab(text: 'Practice  ${upcoming.length}'),
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
                            cards: upcoming,
                            nextStatus: LearningStatus.active,
                            actionLabel: 'Activate',
                            emptyText:
                                'Move Future cards here to practice.',
                            dashboard: data,
                            showScheduleStatus: true,
                          ),
                          LearningCardsTab(
                            cards: learning,
                            showScheduleStatus: true,
                            emptyText: category == 'Script'
                                ? 'No letters are currently being learned.'
                                : widget.allCards || widget.tagSystem != null
                                ? 'No cards are currently being learned.'
                                : 'No words are currently being learned.',

                            dashboard: data,
                          ),
                          LearningCardsTab(
                            cards: learnt,
                            showScheduleStatus: true,
                            emptyText: category == 'Script'
                                ? 'No letters have reached 80% yet.'
                                : widget.allCards || widget.tagSystem != null
                                ? 'No cards have reached 80% yet.'
                                : 'No words have reached 80% yet.',
                            dashboard: data,
                          ),
                          LearningCardsTab(
                            cards: notStarted,
                            priorityScores: futureScores,
                            emptyText: category == 'Script'
                                ? 'Every letter has been started.'
                                : widget.allCards || widget.tagSystem != null
                                ? 'Every card has been started.'
                                : 'Every word has been started.',
                            nextStatus: LearningStatus.prep,
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

IconData categoryIcon(String category) => switch (category.toLowerCase()) {
  'word' => Icons.text_fields,
  'phrase' => Icons.chat_bubble_outline,
  'noun' => Icons.inventory_2_outlined,
  'verb' => Icons.directions_run_outlined,
  'adjective' => Icons.tune_outlined,
  'adverb' => Icons.speed_outlined,
  'postposition' => Icons.alt_route_outlined,
  'script' => Icons.gesture_outlined,
  _ => Icons.text_fields_outlined,
};
