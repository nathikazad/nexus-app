import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/book_page.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_error.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/card_list/card_metric.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_schema.dart';
import 'package:nx_cards/browser/language/language_page.dart';
import 'package:nx_cards/settings/settings_page.dart';
import 'package:nx_db/riverpod.dart';

class BrowserPage extends ConsumerWidget {
  const BrowserPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schema = ref.watch(cardsSchemaStatusProvider);
    return schema.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => BrowserLoadError(
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
      error: (error, _) => BrowserLoadError(
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
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
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
                            builder: (_) => LanguagePage(language: language),
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
                              builder: (_) => BookPage(
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
                      CardMetric(
                        icon: Icons.style_outlined,
                        value: total,
                        label: 'Total',
                      ),
                      CardMetric(
                        icon: Icons.schedule_outlined,
                        value: due,
                        label: 'Due',
                      ),
                      CardMetric(
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
