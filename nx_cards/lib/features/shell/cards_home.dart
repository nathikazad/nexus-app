import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/data/remote/kgql/card_schema.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/cards/card_details_dialog.dart';
import 'package:nx_cards/features/cards/card_editors.dart';
import 'package:nx_cards/features/shell/word_category_order.dart';
import 'package:nx_cards/features/study/study_screen.dart';
import 'package:nx_cards/features/study/study_setup_screen.dart';
import 'package:nx_cards/features/shell/word_schedule_status.dart';
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
                    'Create the FlashcardDeck, Flashcard, and LanguageFlashcard KGQL model types, including deck language and card topics.',
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
      data: (data) => _WordCategoriesDashboard(data: data),
    );
    return Scaffold(body: SafeArea(child: body));
  }
}

class _WordCategoriesDashboard extends ConsumerWidget {
  const _WordCategoriesDashboard({required this.data});

  final CardsDashboard data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = orderedWordCategories(
      data.cards
          .where((card) => card.isWordCard)
          .map((card) => card.wordCategory),
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
                              child: _WordCategoryCard(
                                category: category,
                                data: data,
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

class _WordCategoryCard extends StatelessWidget {
  const _WordCategoryCard({required this.category, required this.data});

  final String category;
  final CardsDashboard data;

  @override
  Widget build(BuildContext context) {
    final cards = data.cards
        .where((card) => card.wordCategory == category)
        .toList(growable: false);
    final current = cards
        .where((card) => card.learningStatus == LearningStatus.learning)
        .length;
    final due = data.dueCount(DateTime.now(), wordCategory: category);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WordCategoryScreen(category: category),
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
              const SizedBox(height: 5),
              Text(
                '$current currently learning · ${cards.length - current} available',
                style: const TextStyle(fontSize: 12, color: RecallColors.muted),
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 13),
              Row(
                children: [
                  _SmallCount(
                    value: due,
                    label: 'Due',
                    color: RecallColors.ink,
                  ),
                  const SizedBox(width: 24),
                  _SmallCount(
                    value: cards.length,
                    label: 'Words',
                    color: RecallColors.ink,
                  ),
                  const Spacer(),
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

class WordCategoryScreen extends ConsumerWidget {
  const WordCategoryScreen({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(cardsDashboardProvider);
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
              .where((card) => card.wordCategory == category)
              .toList(growable: false);
          final now = DateTime.now().toUtc();
          final learning = sortWordsByScheduleState(
            cards.where(
              (card) => card.learningStatus == LearningStatus.learning,
            ),
            now,
          );
          final learnt = sortWordsByScheduleState(
            cards.where((card) => card.learningStatus == LearningStatus.learnt),
            now,
          );
          final notStarted = sortWordsByScheduleState(
            cards.where(
              (card) => card.learningStatus == LearningStatus.notStarted,
            ),
            now,
          );
          final queue = data.studyQueue(
            DateTime.now(),
            wordCategory: category,
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
                              '${cards.length} words · ${learning.length} learning',
                              style: const TextStyle(color: RecallColors.muted),
                            ),
                          ),
                          _StudyLauncher(
                            title: category,
                            preferenceKey: 'word-category:$category',
                            prompts: queue,
                            studyCards: [...learning, ...learnt],
                            languagePair: _languagesForCards(data, cards),
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
                        emptyText: 'No words are currently being learned.',
                        previousStatus: LearningStatus.notStarted,
                        previousActionLabel: '←',
                        nextStatus: LearningStatus.learnt,
                        actionLabel: '✓',
                        dashboard: data,
                      ),
                      _LearningTab(
                        cards: learnt,
                        emptyText: 'No words have been marked learnt yet.',
                        previousStatus: LearningStatus.learning,
                        previousActionLabel: '←',
                        dashboard: data,
                      ),
                      _LearningTab(
                        cards: notStarted,
                        emptyText: 'Every word has been started.',
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
    this.previousStatus,
    this.previousActionLabel,
    this.nextStatus,
    this.actionLabel,
  });

  final List<StudyCard> cards;
  final String emptyText;
  final CardsDashboard dashboard;
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
                            deck: dashboard.decks
                                .where((deck) => deck.id == card.deckId)
                                .firstOrNull,
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
    required this.deck,
    this.previousStatus,
    this.previousActionLabel,
    this.nextStatus,
    this.actionLabel,
  });

  final StudyCard card;
  final CardDeck? deck;
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
    final deck = widget.deck;
    if (deck == null) return;
    final edit = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CardDetailsPage(deck: deck, card: widget.card),
      ),
    );
    if (edit == true && mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => CardEditorDialog(deck: deck, card: widget.card),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.card.content;
    final transliteration = content is LanguageCardContent
        ? content.transliteration
        : '';
    final scheduleStatus = wordScheduleStatus(
      widget.card,
      DateTime.now().toUtc(),
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
                              if (scheduleStatus != null &&
                                  scheduleStatus.label != 'New') ...[
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

  final WordScheduleStatus status;

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
        status.recallPercentage == null
            ? status.label.toUpperCase()
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

// Kept as the deck-management surface while the primary library view is
// category-based. Decks remain part of the storage and study model.
// ignore: unused_element
class _DecksDashboard extends ConsumerWidget {
  const _DecksDashboard({required this.data});
  final CardsDashboard data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final due = data.dueCount(now);
    final fresh = data.newCount();
    final queue = data.studyQueue(now);
    return RefreshIndicator(
      onRefresh: ref.read(cardsLibrarySyncProvider),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    runSpacing: 18,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_dateLabel(now), style: monoLabel),
                          const SizedBox(height: 8),
                          const Text(
                            'Ready to remember?',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$due cards due · $fresh new',
                            style: const TextStyle(color: RecallColors.muted),
                          ),
                        ],
                      ),
                      _StudyLauncher(
                        title: "Today's review",
                        preferenceKey: 'today-review',
                        prompts: queue,
                        studyCards: _studyCardsForPrompts(queue),
                        languagePair: _languagesForPrompts(data, queue),
                        builder: (onPressed) => FilledButton.icon(
                          onPressed: onPressed,
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text('Start review'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Due now',
                          value: '$due',
                          detail: 'Ready for review',
                          accent: RecallColors.orange,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _MetricCard(
                          label: 'New cards',
                          value: '$fresh',
                          detail: 'Up to 20 per session',
                          accent: RecallColors.violet,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _MetricCard(
                          label: 'Total cards',
                          value: '${data.cards.length}',
                          detail: '${data.decks.length} decks',
                          accent: RecallColors.emerald,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  const Text(
                    'Your decks',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose a deck to study or manage its cards.',
                    style: TextStyle(fontSize: 12, color: RecallColors.muted),
                  ),
                  const SizedBox(height: 15),
                  if (data.decks.isEmpty)
                    _EmptyDecks(
                      onCreate: () => showDialog<void>(
                        context: context,
                        builder: (_) => const CreateDeckDialog(),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth >= 720
                            ? (constraints.maxWidth - 14) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            for (final deck in data.decks.where(
                              (d) => !d.archived,
                            ))
                              SizedBox(
                                width: width,
                                child: _DeckCard(deck: deck, data: data),
                              ),
                            SizedBox(
                              width: width,
                              child: _AddDeckCard(
                                onTap: () => showDialog<void>(
                                  context: context,
                                  builder: (_) => const CreateDeckDialog(),
                                ),
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

class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.deck, required this.data});
  final CardDeck deck;
  final CardsDashboard data;

  @override
  Widget build(BuildContext context) {
    final due = data.dueCount(DateTime.now(), deckId: deck.id);
    final queue = data.studyQueue(DateTime.now(), deckId: deck.id);
    final color = !deck.isLanguageDeck ? RecallColors.sky : RecallColors.violet;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => DeckDetailScreen(deck: deck)),
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
                  color: color.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  !deck.isLanguageDeck
                      ? Icons.menu_book_outlined
                      : Icons.translate_outlined,
                  color: color,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deck.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (deck.isLanguageDeck)
                    _Pill(
                      '${deck.fromLanguage} → ${deck.toLanguage}',
                      color: color,
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                deck.description.isEmpty ? 'No description' : deck.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: RecallColors.muted),
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  _SmallCount(
                    value: due,
                    label: 'Due',
                    color: due == 0
                        ? RecallColors.emerald
                        : RecallColors.orange,
                  ),
                  const SizedBox(width: 24),
                  _SmallCount(
                    value: data.cardCount(deck.id),
                    label: 'Cards',
                    color: RecallColors.ink,
                  ),
                  const Spacer(),
                  if (queue.isNotEmpty)
                    _StudyLauncher(
                      title: deck.name,
                      preferenceKey: 'deck:${deck.id}',
                      prompts: queue,
                      studyCards: data.cards
                          .where((card) => card.deckId == deck.id)
                          .toList(growable: false),
                      languagePair: deck.isLanguageDeck
                          ? _LanguagePair(deck.fromLanguage!, deck.toLanguage!)
                          : null,
                      builder: (onPressed) => FilledButton(
                        onPressed: onPressed,
                        child: const Text(
                          'Study  →',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                  else
                    OutlinedButton(
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeckDetailScreen(deck: deck),
                        ),
                      ),
                      child: const Text(
                        'Browse',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeckDetailScreen extends ConsumerStatefulWidget {
  const DeckDetailScreen({super.key, required this.deck});
  final CardDeck deck;

  @override
  ConsumerState<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends ConsumerState<DeckDetailScreen> {
  CardDeck get deck => widget.deck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(cardDeckSyncProvider)(deck.id).catchError((_) {}));
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(cardsDashboardProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(deck.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CardEditorDialog(deck: deck),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New card'),
            ),
          ),
        ],
      ),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(
          error: error,
          onRetry: () => ref.invalidate(cardsDashboardProvider),
        ),
        data: (data) {
          final allCards = data.cards
              .where((card) => card.deckId == deck.id)
              .toList();
          final cards = allCards;
          final queue = data.studyQueue(
            DateTime.now(),
            deckId: deck.id,
            newCardLimit: allCards.length * StudyCue.values.length,
          );
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              deck.description.isEmpty
                                  ? '${cards.length} cards'
                                  : deck.description,
                              style: const TextStyle(color: RecallColors.muted),
                            ),
                          ),
                          _StudyLauncher(
                            title: deck.name,
                            preferenceKey: 'deck:${deck.id}',
                            prompts: queue,
                            studyCards: allCards,
                            languagePair: deck.isLanguageDeck
                                ? _LanguagePair(
                                    deck.fromLanguage!,
                                    deck.toLanguage!,
                                  )
                                : null,
                            builder: (onPressed) => FilledButton(
                              onPressed: onPressed,
                              child: const Text('Study'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      if (cards.isEmpty)
                        _EmptyCards(
                          onCreate: () => showDialog<void>(
                            context: context,
                            builder: (_) => CardEditorDialog(deck: deck),
                          ),
                        )
                      else
                        for (final card in cards)
                          _CardRow(card: card, deck: deck),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CardRow extends ConsumerWidget {
  const _CardRow({required this.card, required this.deck});
  final StudyCard card;
  final CardDeck deck;

  Future<void> _showDetails(BuildContext context) async {
    final edit = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CardDetailsPage(deck: deck, card: card),
      ),
    );
    if (edit != true || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => CardEditorDialog(deck: deck, card: card),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _showDetails(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(
          card.suspended ? Icons.pause_circle_outline : Icons.style_outlined,
          color: card.suspended ? RecallColors.faint : RecallColors.violet,
        ),
        title: Text(card.front, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            [
              card.back,
              if (card.sourceBookName != null) card.sourceBookName!,
            ].join('  •  '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            final repository = ref.read(cardsRepositoryProvider);
            if (action == 'edit') {
              await showDialog<void>(
                context: context,
                builder: (_) => CardEditorDialog(deck: deck, card: card),
              );
            } else if (action == 'suspend') {
              await repository.setSuspended(card, !card.suspended);
              ref.invalidate(cardsDashboardProvider);
            } else if (action == 'delete') {
              await repository.deleteCard(card.id);
              ref.invalidate(cardsDashboardProvider);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
              value: 'suspend',
              child: Text(card.suspended ? 'Unsuspend' : 'Suspend'),
            ),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

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
  });

  final String title;
  final List<StudyPrompt> prompts;
  final List<StudyCard> studyCards;
  final String preferenceKey;
  final _StudyButtonBuilder builder;
  final _LanguagePair? languagePair;

  @override
  Widget build(BuildContext context) {
    final hasLanguageCards = studyCards.any((card) => card.isLanguageCard);
    if (prompts.isEmpty && !hasLanguageCards) return builder(null);
    if (languagePair == null || !hasLanguageCards) {
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
            fromLanguage: languagePair!.from,
            toLanguage: languagePair!.to,
            preferenceKey:
                '$preferenceKey:${languagePair!.from}:${languagePair!.to}',
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
  final deckIds = prompts
      .where((prompt) => prompt.card.isLanguageCard)
      .map((prompt) => prompt.card.deckId)
      .toSet();
  final pairs = dashboard.decks
      .where((deck) => deckIds.contains(deck.id))
      .where((deck) => deck.isLanguageDeck)
      .map((deck) => _LanguagePair(deck.fromLanguage!, deck.toLanguage!))
      .toSet();
  return pairs.length == 1 ? pairs.single : null;
}

_LanguagePair? _languagesForCards(
  CardsDashboard dashboard,
  Iterable<StudyCard> cards,
) {
  final deckIds = cards
      .where((card) => card.isLanguageCard)
      .map((card) => card.deckId)
      .toSet();
  final pairs = dashboard.decks
      .where((deck) => deckIds.contains(deck.id))
      .where((deck) => deck.isLanguageDeck)
      .map((deck) => _LanguagePair(deck.fromLanguage!, deck.toLanguage!))
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

class _AddDeckCard extends StatelessWidget {
  const _AddDeckCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      height: 225,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RecallColors.line),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: RecallColors.soft,
            child: Icon(Icons.add, color: RecallColors.muted),
          ),
          SizedBox(height: 10),
          Text(
            'Create a new deck',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'Start collecting what matters',
            style: TextStyle(fontSize: 11, color: RecallColors.faint),
          ),
        ],
      ),
    ),
  );
}

class _EmptyDecks extends StatelessWidget {
  const _EmptyDecks({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => _EmptyPanel(
    icon: Icons.layers_outlined,
    title: 'No decks yet',
    detail: 'Create a deck, then add your first card.',
    action: 'Create deck',
    onAction: onCreate,
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
