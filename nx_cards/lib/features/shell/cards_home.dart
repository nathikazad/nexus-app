import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/data/remote/kgql/card_schema.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/cards/card_details_dialog.dart';
import 'package:nx_cards/features/cards/card_editors.dart';
import 'package:nx_cards/features/study/study_screen.dart';
import 'package:nx_db/riverpod.dart';

class CardsHome extends ConsumerStatefulWidget {
  const CardsHome({super.key, required this.initialTab});
  final int initialTab;

  @override
  ConsumerState<CardsHome> createState() => _CardsHomeState();
}

class _CardsHomeState extends ConsumerState<CardsHome> {
  late int _tab = widget.initialTab;

  void _selectTab(int value) {
    if (_tab == value) return;
    setState(() => _tab = value);
    context.go(value == 0 ? '/decks' : '/today');
  }

  @override
  Widget build(BuildContext context) {
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
        return _HomeScaffold(tab: _tab, onSelectTab: _selectTab);
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
                    'Create the FlashcardDeck, Flashcard, and LanguageFlashcard KGQL model types, including language and card tag systems.',
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
  const _HomeScaffold({required this.tab, required this.onSelectTab});
  final int tab;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final dashboard = ref.watch(cardsDashboardProvider);
    final body = dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _LoadError(
        error: error,
        onRetry: () => ref.invalidate(cardsDashboardProvider),
      ),
      data: (data) =>
          tab == 0 ? _DecksDashboard(data: data) : _TodayView(data: data),
    );
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 24,
        title: wide
            ? const _SearchPlaceholder()
            : const Row(
                children: [
                  _RecallMark(),
                  SizedBox(width: 10),
                  Text(
                    'recall',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: FilledButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const CreateDeckDialog(),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('New deck'),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            _SideNav(
              tab: tab,
              onSelect: onSelectTab,
              dashboard: dashboard.value,
            ),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: onSelectTab,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.layers_outlined),
                  selectedIcon: Icon(Icons.layers),
                  label: 'Your decks',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_today_outlined),
                  selectedIcon: Icon(Icons.calendar_today),
                  label: 'Today',
                ),
              ],
            ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.tab,
    required this.onSelect,
    required this.dashboard,
  });
  final int tab;
  final ValueChanged<int> onSelect;
  final CardsDashboard? dashboard;

  @override
  Widget build(BuildContext context) {
    final due = dashboard?.dueCount(DateTime.now()) ?? 0;
    return Container(
      width: 252,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: RecallColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
      child: Column(
        children: [
          const Row(
            children: [
              _RecallMark(),
              SizedBox(width: 11),
              Text(
                'recall',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 34),
          _NavTile(
            icon: Icons.layers_outlined,
            label: 'Your decks',
            selected: tab == 0,
            onTap: () => onSelect(0),
          ),
          _NavTile(
            icon: Icons.calendar_today_outlined,
            label: 'Today',
            selected: tab == 1,
            badge: due,
            onTap: () => onSelect(1),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RecallColors.soft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RecallColors.line),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xffffe4e6),
                  child: Icon(
                    Icons.person_outline,
                    size: 17,
                    color: RecallColors.rose,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nexus learner',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'FSRS · 90%',
                        style: TextStyle(
                          fontSize: 11,
                          color: RecallColors.faint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      tileColor: selected ? RecallColors.soft : null,
      leading: Icon(
        icon,
        size: 20,
        color: selected ? RecallColors.ink : RecallColors.muted,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? RecallColors.ink : RecallColors.muted,
        ),
      ),
      trailing: badge == null || badge == 0 ? null : _CountBadge(badge!),
      onTap: onTap,
    ),
  );
}

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
                      FilledButton.icon(
                        onPressed: queue.isEmpty
                            ? null
                            : () =>
                                  _openStudy(context, "Today's review", queue),
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text('Start review'),
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
    final color = deck.language == null
        ? RecallColors.sky
        : RecallColors.violet;
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
                  deck.language == null
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
                  if (deck.language != null)
                    _Pill(deck.language!, color: color),
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
                    FilledButton(
                      onPressed: () => _openStudy(context, deck.name, queue),
                      child: const Text(
                        'Study  →',
                        style: TextStyle(fontSize: 12),
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

class _TodayView extends StatelessWidget {
  const _TodayView({required this.data});
  final CardsDashboard data;

  @override
  Widget build(BuildContext context) {
    final queue = data.studyQueue(DateTime.now());
    final grouped = <String, int>{};
    for (final prompt in queue) {
      grouped.update(
        prompt.card.deckName,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('YOUR QUEUE', style: monoLabel),
                const SizedBox(height: 8),
                const Text(
                  "Today's review",
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'A focused queue across all of your decks.',
                  style: TextStyle(color: RecallColors.muted),
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xfffff7ed),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.schedule,
                            color: RecallColors.orange,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                queue.isEmpty
                                    ? 'All caught up'
                                    : '${queue.length} cards awaiting you',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                grouped.entries
                                    .map((e) => '${e.value} ${e.key}')
                                    .join(' · '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: RecallColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: queue.isEmpty
                              ? null
                              : () => _openStudy(
                                  context,
                                  "Today's review",
                                  queue,
                                ),
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('Begin session'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
  String? _selectedTag;

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
          final tags = allCards.expand((card) => card.tags).toSet().toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          final cards = _selectedTag == null
              ? allCards
              : allCards
                    .where((card) => card.tags.contains(_selectedTag))
                    .toList();
          final queue = data.studyQueue(DateTime.now(), deckId: deck.id);
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
                          FilledButton.icon(
                            onPressed: queue.isEmpty
                                ? null
                                : () => _openStudy(context, deck.name, queue),
                            icon: const Icon(Icons.play_circle_outline),
                            label: Text('Study ${queue.length}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      if (tags.isNotEmpty) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('All'),
                                selected: _selectedTag == null,
                                onSelected: (_) =>
                                    setState(() => _selectedTag = null),
                              ),
                              const SizedBox(width: 7),
                              for (final tag in tags) ...[
                                ChoiceChip(
                                  label: Text(tag),
                                  selected: _selectedTag == tag,
                                  onSelected: (_) =>
                                      setState(() => _selectedTag = tag),
                                ),
                                const SizedBox(width: 7),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (cards.isEmpty)
                        _selectedTag == null
                            ? _EmptyCards(
                                onCreate: () => showDialog<void>(
                                  context: context,
                                  builder: (_) => CardEditorDialog(deck: deck),
                                ),
                              )
                            : const _EmptyTagResult()
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
    final edit = await showDialog<bool>(
      context: context,
      builder: (_) => CardDetailsDialog(deck: deck, card: card),
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
              if (card.tags.isNotEmpty) card.tags.join(' · '),
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

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.value);
  final int value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xffffedd5),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      '$value',
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        color: RecallColors.orange,
      ),
    ),
  );
}

class _RecallMark extends StatelessWidget {
  const _RecallMark();
  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: RecallColors.ink,
      borderRadius: BorderRadius.circular(9),
    ),
    child: const Text(
      'r',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ),
  );
}

class _SearchPlaceholder extends StatelessWidget {
  const _SearchPlaceholder();
  @override
  Widget build(BuildContext context) => Container(
    width: 300,
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: RecallColors.soft,
      borderRadius: BorderRadius.circular(9),
    ),
    child: const Row(
      children: [
        Icon(Icons.search, size: 18, color: RecallColors.faint),
        SizedBox(width: 8),
        Text(
          'Search cards and decks',
          style: TextStyle(fontSize: 12, color: RecallColors.faint),
        ),
        Spacer(),
        Text(
          '⌘ K',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: RecallColors.faint,
          ),
        ),
      ],
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

class _EmptyTagResult extends StatelessWidget {
  const _EmptyTagResult();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Center(
        child: Text(
          'No cards match this tag.',
          style: TextStyle(color: RecallColors.muted),
        ),
      ),
    ),
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
