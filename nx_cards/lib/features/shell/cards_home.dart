import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/data/remote/kgql/card_schema.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/cards/card_details_dialog.dart';
import 'package:nx_cards/features/shell/language_category_order.dart';
import 'package:nx_cards/features/study/study_screen.dart';
import 'package:nx_cards/features/study/study_setup_screen.dart';
import 'package:nx_cards/features/shell/word_schedule_status.dart';
import 'package:nx_cards/features/settings/review_progression_settings_page.dart';
import 'package:nx_cards/features/settings/review_progression_settings.dart';
import 'package:nx_db/riverpod.dart';

class CardsHome extends ConsumerWidget {
  const CardsHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schema = ref.watch(cardsSchemaStatusProvider);
    return schema.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => _LoadError(
        error: error,
        onRetry: () => ref.invalidate(cardsSchemaStatusProvider),
      ),
      data: (status) {
        if (!status.ready) return _SchemaSetup(status: status);
        return const _HomeScaffold();
      },
    );
  }
}

class _SchemaSetup extends ConsumerStatefulWidget {
  const _SchemaSetup({required this.status});
  final CardsSchemaStatus status;

  @override
  ConsumerState<_SchemaSetup> createState() => _SchemaSetupState();
}

class _SchemaSetupState extends ConsumerState<_SchemaSetup> {
  bool _working = false;

  Future<void> _setup() async {
    setState(() => _working = true);
    try {
      await bootstrapCardsSchema(ref.read(graphqlClientProvider));
      ref.invalidate(cardsSchemaStatusProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Schema setup failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: RecallColors.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'r',
                      style: TextStyle(color: Colors.white, fontSize: 22),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Set up Recall',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create the Flashcard and LanguageFlashcard KGQL model types used by Recall.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: RecallColors.muted, height: 1.45),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _working ? null : _setup,
                    icon: const Icon(Icons.schema_outlined),
                    label: Text(
                      _working ? 'Creating schema…' : 'Create KGQL models',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeScaffold extends ConsumerWidget {
  const _HomeScaffold();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(cardsDashboardProvider);
    final body = dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _LoadError(
        error: error,
        onRetry: () => ref.invalidate(cardsDashboardProvider),
      ),
      data: (data) => _SourcesDashboard(data: data),
    );
    return Scaffold(
      backgroundColor: RecallColors.soft,
      appBar: AppBar(
        title: const Text(
          'Library',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Review settings',
            icon: const Icon(Icons.tune_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ReviewProgressionSettingsPage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: body,
    );
  }
}

class _SourcesDashboard extends StatelessWidget {
  const _SourcesDashboard({required this.data});

  final CardsDashboard data;

  @override
  Widget build(BuildContext context) {
    final booksById = <int, String>{};
    for (final card in data.cards) {
      final id = card.sourceBookId;
      if (id != null) booksById[id] = card.sourceBookName ?? 'Book $id';
    }
    final books = booksById.entries.toList()
      ..sort((left, right) => left.value.compareTo(right.value));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _LibrarySectionTitle(
                  title: 'Languages',
                  subtitle:
                      'Choose a language, then script, words, or phrases.',
                ),
                const SizedBox(height: 12),
                _SourceGrid(
                  children: [
                    for (final language in data.languages)
                      _SourceCard(
                        title: language,
                        icon: Icons.translate_outlined,
                        color: RecallColors.violet,
                        total: data.cardsForLanguage(language).length,
                        due: data.dueCount(DateTime.now(), language: language),
                        current: data
                            .cardsForLanguage(language)
                            .where(
                              (card) =>
                                  card.learningStatus ==
                                  LearningStatus.learning,
                            )
                            .length,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                LanguageHomeScreen(language: language),
                          ),
                        ),
                      ),
                  ],
                ),
                if (books.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  const _LibrarySectionTitle(
                    title: 'Books',
                    subtitle: 'Open a book to browse all of its flashcards.',
                  ),
                  const SizedBox(height: 12),
                  _SourceGrid(
                    children: [
                      for (final book in books)
                        _SourceCard(
                          title: book.value,
                          icon: Icons.menu_book_outlined,
                          color: RecallColors.sky,
                          total: data.cardsForBook(book.key).length,
                          due: data.dueCount(DateTime.now(), bookId: book.key),
                          current: data
                              .cardsForBook(book.key)
                              .where(
                                (card) =>
                                    card.learningStatus ==
                                    LearningStatus.learning,
                              )
                              .length,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BookCardsScreen(
                                bookId: book.key,
                                bookName: book.value,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LibrarySectionTitle extends StatelessWidget {
  const _LibrarySectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: RecallColors.muted),
      ),
    ],
  );
}

class _SourceGrid extends StatelessWidget {
  const _SourceGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth >= 720
          ? (constraints.maxWidth - 14) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.total,
    required this.due,
    required this.current,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final int total;
  final int due;
  final int current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _SourceMetric(
                        icon: Icons.style_outlined,
                        value: total,
                        label: 'Total',
                      ),
                      _SourceMetric(
                        icon: Icons.schedule_outlined,
                        value: due,
                        label: 'Due',
                      ),
                      _SourceMetric(
                        icon: Icons.school_outlined,
                        value: current,
                        label: 'Current',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    ),
  );
}

class _SourceMetric extends StatelessWidget {
  const _SourceMetric({
    required this.icon,
    required this.value,
    required this.label,
    this.stacked = false,
  });

  final IconData icon;
  final int value;
  final String label;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: RecallColors.muted),
              const SizedBox(width: 5),
              Text(
                '$value',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: RecallColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: RecallColors.faint),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: RecallColors.muted),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: const TextStyle(fontSize: 12, color: RecallColors.muted),
        ),
      ],
    );
  }
}

class LanguageHomeScreen extends ConsumerWidget {
  const LanguageHomeScreen({super.key, required this.language});

  final String language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(cardsDashboardProvider);
    return Scaffold(
      appBar: AppBar(title: Text(language)),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(
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
    final due = data.dueCount(
      DateTime.now(),
      studyCategory: category,
      language: language,
    );
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                LanguageCategoryScreen(category: category, language: language),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: RecallColors.soft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: RecallColors.line),
                ),
                child: Icon(_categoryIcon(category), color: RecallColors.ink),
              ),
              const SizedBox(height: 17),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: _SourceMetric(
                      icon: Icons.style_outlined,
                      value: cards.length,
                      label: 'Total',
                      stacked: true,
                    ),
                  ),
                  Expanded(
                    child: _SourceMetric(
                      icon: Icons.schedule_outlined,
                      value: due,
                      label: 'Due',
                      stacked: true,
                    ),
                  ),
                  Expanded(
                    child: _SourceMetric(
                      icon: Icons.school_outlined,
                      value: current,
                      label: 'Current',
                      stacked: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LanguageCategoryScreen extends ConsumerWidget {
  const LanguageCategoryScreen({
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
        error: (error, _) => _LoadError(
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
                          _StudyLauncher(
                            title: language == null
                                ? category
                                : '$language · $category',
                            preferenceKey:
                                'language-category:${language ?? 'all'}:$category',
                            prompts: queue,
                            studyCards: [...learning, ...learnt],
                            languagePair: language == null
                                ? _languagesForCards(data, cards)
                                : _LanguagePair('Front', language!),
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
                      _LearningTab(
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
                      _LearningTab(
                        cards: learnt,
                        emptyText: category == 'Script'
                            ? 'No letters have been marked learnt yet.'
                            : 'No words have been marked learnt yet.',
                        previousStatus: LearningStatus.learning,
                        previousActionLabel: '←',
                        dashboard: data,
                      ),
                      _LearningTab(
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

class BookCardsScreen extends ConsumerWidget {
  const BookCardsScreen({
    super.key,
    required this.bookId,
    required this.bookName,
  });

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
        error: (error, _) => _LoadError(
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
                          _StudyLauncher(
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
                      _LearningTab(
                        cards: learning,
                        showScheduleStatus: true,
                        emptyText: 'No cards are currently being learned.',
                        previousStatus: LearningStatus.notStarted,
                        previousActionLabel: '←',
                        nextStatus: LearningStatus.learnt,
                        actionLabel: '✓',
                        dashboard: data,
                      ),
                      _LearningTab(
                        cards: learnt,
                        emptyText: 'No cards have been moved to Past yet.',
                        previousStatus: LearningStatus.learning,
                        previousActionLabel: '←',
                        dashboard: data,
                      ),
                      _LearningTab(
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

class _LearningTab extends ConsumerWidget {
  const _LearningTab({
    required this.cards,
    required this.emptyText,
    required this.dashboard,
    this.showScheduleStatus = false,
    this.previousStatus,
    this.previousActionLabel,
    this.nextStatus,
    this.actionLabel,
  });

  final List<StudyCard> cards;
  final String emptyText;
  final CardsDashboard dashboard;
  final bool showScheduleStatus;
  final LearningStatus? previousStatus;
  final String? previousActionLabel;
  final LearningStatus? nextStatus;
  final String? actionLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
    onRefresh: ref.read(cardsLibrarySyncProvider),
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: cards.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: RecallColors.soft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: RecallColors.line),
                    ),
                    child: Text(
                      emptyText,
                      style: const TextStyle(color: RecallColors.muted),
                    ),
                  )
                : Column(
                    children: [
                      for (final card in cards)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: _LearningStatusRow(
                            key: ValueKey(
                              '${card.learningStatus.storageValue}:${card.id}',
                            ),
                            card: card,
                            showScheduleStatus: showScheduleStatus,
                            previousStatus: previousStatus,
                            previousActionLabel: previousActionLabel,
                            nextStatus: nextStatus,
                            actionLabel: actionLabel,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    ),
  );
}

class _LearningStatusRow extends ConsumerStatefulWidget {
  const _LearningStatusRow({
    super.key,
    required this.card,
    required this.showScheduleStatus,
    this.previousStatus,
    this.previousActionLabel,
    this.nextStatus,
    this.actionLabel,
  });

  final StudyCard card;
  final bool showScheduleStatus;
  final LearningStatus? previousStatus;
  final String? previousActionLabel;
  final LearningStatus? nextStatus;
  final String? actionLabel;

  @override
  ConsumerState<_LearningStatusRow> createState() => _LearningStatusRowState();
}

class _LearningStatusRowState extends ConsumerState<_LearningStatusRow> {
  static const _actionWidth = 70.0;
  double _offset = 0;
  bool _dragging = false;
  bool _working = false;

  bool get _canDrag =>
      widget.previousStatus != null || widget.nextStatus != null;

  void _drag(DragUpdateDetails details) {
    if (!_canDrag) return;
    final minimum = widget.nextStatus == null ? 0.0 : -_actionWidth;
    final maximum = widget.previousStatus == null ? 0.0 : _actionWidth;
    setState(() {
      _dragging = true;
      _offset = (_offset + details.delta.dx).clamp(minimum, maximum).toDouble();
    });
  }

  void _finishDrag(DragEndDetails details) {
    final reveal = _offset.abs() >= _actionWidth * .42;
    final status = _offset < 0 ? widget.nextStatus : widget.previousStatus;
    setState(() {
      _dragging = false;
      _offset = reveal && status != null
          ? (_offset < 0 ? -_actionWidth : _actionWidth)
          : 0;
    });
    if (reveal && status != null) _changeStatus(status);
  }

  Future<void> _changeStatus(LearningStatus status) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await ref
          .read(cardsRepositoryProvider)
          .setLearningStatus(widget.card, status);
      ref.invalidate(cardsDashboardProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update word: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _offset = 0;
        });
      }
    }
  }

  Future<void> _showDetails() async {
    if (_offset != 0) {
      setState(() => _offset = 0);
      return;
    }
    final edit = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CardDetailsPage(card: widget.card)),
    );
    if (edit == true && mounted) ref.invalidate(cardsDashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.card.content;
    final transliteration = content is LanguageCardContent
        ? content.transliteration
        : '';
    final scheduleStatus = cardScheduleStatus(
      widget.card,
      DateTime.now().toUtc(),
      historyWindow:
          ref.watch(reviewProgressionSettingsProvider).value?.historyWindow ??
          5,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: RecallColors.ink,
              child: Stack(
                children: [
                  if (widget.previousStatus case final status?)
                    _statusAction(
                      alignment: Alignment.centerLeft,
                      status: status,
                      label: widget.previousActionLabel ?? '',
                    ),
                  if (widget.nextStatus case final status?)
                    _statusAction(
                      alignment: Alignment.centerRight,
                      status: status,
                      label: widget.actionLabel ?? '',
                    ),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _working || !_canDrag ? null : _drag,
              onHorizontalDragEnd: _working || !_canDrag ? null : _finishDrag,
              onTap: _working ? null : _showDetails,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: RecallColors.line),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.card.front,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (widget.showScheduleStatus &&
                                  scheduleStatus != null) ...[
                                const SizedBox(width: 9),
                                _ScheduleStatePill(status: scheduleStatus),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              widget.card.back,
                              if (transliteration.isNotEmpty) transliteration,
                            ].join('  ·  '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: RecallColors.muted,
                            ),
                          ),
                          if (scheduleStatus?.isDue == true) ...[
                            const SizedBox(height: 7),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  key: ValueKey('word-schedule-due'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: RecallColors.ink,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'DUE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'monospace',
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: .7,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.drag_indicator,
                      size: 17,
                      color: RecallColors.faint,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusAction({
    required Alignment alignment,
    required LearningStatus status,
    required String label,
  }) => Align(
    alignment: alignment,
    child: SizedBox(
      width: _actionWidth,
      child: InkWell(
        onTap: _working ? null : () => _changeStatus(status),
        child: Center(
          child: _working
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w400,
                  ),
                ),
        ),
      ),
    ),
  );
}

class _ScheduleStatePill extends StatelessWidget {
  const _ScheduleStatePill({required this.status});

  final CardScheduleStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status.label) {
      'Learning' => (const Color(0xfffff7ed), RecallColors.orange),
      'Relearning' => (const Color(0xfffff1f2), RecallColors.rose),
      'Retained' => (const Color(0xffecfdf5), RecallColors.emerald),
      'New' => (const Color(0xfff0f9ff), RecallColors.sky),
      _ => (RecallColors.soft, RecallColors.muted),
    };
    return Container(
      key: ValueKey<String>('word-state-${status.label.toLowerCase()}'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        status.label == 'New'
            ? 'NEW'
            : '${status.label.toUpperCase()}  ${status.recallPercentage}%',
        style: TextStyle(
          color: foreground,
          fontFamily: 'monospace',
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: .55,
        ),
      ),
    );
  }
}

IconData _categoryIcon(String category) => switch (category) {
  'Noun' => Icons.inventory_2_outlined,
  'Verb' => Icons.directions_run_outlined,
  'Adjective' => Icons.tune_outlined,
  'Adverb' => Icons.speed_outlined,
  'Postposition' => Icons.alt_route_outlined,
  'Script' => Icons.gesture_outlined,
  _ => Icons.text_fields_outlined,
};

Future<void> _openStudy(
  BuildContext context,
  String title,
  List<StudyPrompt> prompts,
) {
  return Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => StudyScreen(title: title, prompts: prompts),
    ),
  );
}

typedef _StudyButtonBuilder = Widget Function(VoidCallback? onPressed);

class _StudyLauncher extends StatelessWidget {
  const _StudyLauncher({
    required this.title,
    required this.prompts,
    required this.studyCards,
    required this.preferenceKey,
    required this.builder,
    this.languagePair,
    this.sourceKind = StudySourceKind.language,
  });

  final String title;
  final List<StudyPrompt> prompts;
  final List<StudyCard> studyCards;
  final String preferenceKey;
  final _StudyButtonBuilder builder;
  final _LanguagePair? languagePair;
  final StudySourceKind sourceKind;

  @override
  Widget build(BuildContext context) {
    final hasLanguageCards = studyCards.any((card) => card.isLanguageCard);
    if (prompts.isEmpty && studyCards.isEmpty) return builder(null);
    if (sourceKind == StudySourceKind.language &&
        (languagePair == null || !hasLanguageCards)) {
      if (prompts.isEmpty) return builder(null);
      return builder(() => _openStudy(context, title, prompts));
    }
    return builder(
      () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StudySetupScreen(
            title: title,
            prompts: prompts,
            studyCards: studyCards,
            fromLanguage: languagePair?.from ?? 'Question',
            toLanguage: languagePair?.to ?? 'Answer',
            sourceKind: sourceKind,
            preferenceKey: sourceKind == StudySourceKind.book
                ? preferenceKey
                : '$preferenceKey:${languagePair!.from}:${languagePair!.to}',
          ),
        ),
      ),
    );
  }
}

List<StudyCard> _studyCardsForPrompts(List<StudyPrompt> prompts) {
  final cards = <int, StudyCard>{};
  for (final prompt in prompts) {
    cards[prompt.cardId] = prompt.card;
  }
  return cards.values.toList(growable: false);
}

_LanguagePair? _languagesForPrompts(
  CardsDashboard dashboard,
  List<StudyPrompt> prompts,
) {
  final pairs = prompts
      .where((prompt) => prompt.card.isLanguageCard)
      .map((prompt) => dashboard.languageFor(prompt.card))
      .whereType<String>()
      .map((language) => _LanguagePair('Front', language))
      .toSet();
  return pairs.length == 1 ? pairs.single : null;
}

_LanguagePair? _languagesForCards(
  CardsDashboard dashboard,
  Iterable<StudyCard> cards,
) {
  final pairs = cards
      .where((card) => card.isLanguageCard)
      .map(dashboard.languageFor)
      .whereType<String>()
      .map((language) => _LanguagePair('Front', language))
      .toSet();
  return pairs.length == 1 ? pairs.single : null;
}

class _LanguagePair {
  const _LanguagePair(this.from, this.to);
  final String from;
  final String to;

  @override
  bool operator ==(Object other) =>
      other is _LanguagePair && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.accent,
  });
  final String label;
  final String value;
  final String detail;
  final Color accent;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: RecallColors.muted,
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 25,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            style: const TextStyle(fontSize: 11, color: RecallColors.faint),
          ),
        ],
      ),
    ),
  );
}

class _SmallCount extends StatelessWidget {
  const _SmallCount({
    required this.value,
    required this.label,
    required this.color,
  });
  final int value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$value',
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: RecallColors.faint),
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, {required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
    ),
  );
}

class _EmptyCards extends StatelessWidget {
  const _EmptyCards({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => _EmptyPanel(
    icon: Icons.style_outlined,
    title: 'No cards yet',
    detail: 'Add a front and back to begin studying.',
    action: 'Create card',
    onAction: onCreate,
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.detail,
    required this.action,
    required this.onAction,
  });
  final IconData icon;
  final String title;
  final String detail;
  final String action;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(34),
      child: Column(
        children: [
          Icon(icon, size: 40, color: RecallColors.faint),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(detail, style: const TextStyle(color: RecallColors.muted)),
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42, color: RecallColors.rose),
            const SizedBox(height: 12),
            const Text(
              'Could not load cards',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: RecallColors.muted),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    ),
  );
}

String _dateLabel(DateTime date) {
  const weekdays = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];
  const months = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}';
}
