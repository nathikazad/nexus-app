import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nx_cards/account/account_session.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_error.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/language/language_groups.dart';
import 'package:nx_cards/progress/progress_analysis.dart';
import 'package:nx_cards/progress/progress_chart.dart';
import 'package:nx_cards/sync/sync_providers.dart';

typedef ProgressSource = ({String? language, int? bookId});

final progressCardsProvider = FutureProvider.autoDispose
    .family<List<StudyCard>, String>(
      (ref, language) => ref.watch(
        sourceProgressCardsProvider((language: language, bookId: null)).future,
      ),
      retry: (_, _) => null,
    );

final sourceProgressCardsProvider = FutureProvider.autoDispose
    .family<List<StudyCard>, ProgressSource>((ref, source) async {
      ref.watch(activeCardsSessionProvider);
      final local = ref.watch(localCardsStoreProvider);
      final collection = ref.watch(cardsCollectionProvider(source).future);
      final dashboard = await collection.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw StateError(
          'Loading cards took too long. Check your connection and try again.',
        ),
      );
      final cards =
          (source.bookId != null
                  ? dashboard.cardsForBook(source.bookId!)
                  : dashboard.cardsForLanguage(source.language!))
              .toList();
      return Future.wait(
        cards.map((card) async {
          if (!card.isSummary) return card;
          final full = await local?.getCard(card.id);
          if (full == null) {
            throw StateError('Review history is unavailable offline.');
          }
          return full;
        }),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw StateError(
          'Loading review history took too long. Please try again.',
        ),
      );
    }, retry: (_, _) => null);

class ProgressAction extends StatelessWidget {
  const ProgressAction({super.key, required this.language, this.group});
  final String language;
  final LanguageGroup? group;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const ValueKey('open-progress'),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProgressPage(language: language, initialGroup: group),
      ),
    ),
    icon: const Icon(Icons.insights_outlined, size: 20),
    label: const Text('Progress'),
  );
}

class ProgressPage extends ConsumerWidget {
  const ProgressPage({
    super.key,
    required this.language,
    this.initialGroup,
    this.bookId,
  });
  final String language;
  final LanguageGroup? initialGroup;
  final int? bookId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeCardsSessionProvider);
    return Scaffold(
      appBar: AppBar(title: Text('$language · Progress')),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => BrowserLoadError(
          error: e,
          onRetry: () => ref.invalidate(activeCardsSessionProvider),
        ),
        data: (account) {
          if (account == null) {
            return const Center(child: Text('Sign in to view progress.'));
          }
          final key =
              'progress.v1.${account.serverId}.${account.userId}.${account.domainId}.${bookId == null ? language : "book:$bookId"}';
          return ref
              .watch(
                bookId == null
                    ? progressCardsProvider(language)
                    : sourceProgressCardsProvider((
                        language: null,
                        bookId: bookId,
                      )),
              )
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => BrowserLoadError(
                  error: e,
                  onRetry: () {
                    ref.read(cardsInvalidationProvider)();
                    ref.invalidate(progressCardsProvider(language));
                    ref.invalidate(
                      sourceProgressCardsProvider((
                        language: bookId == null ? language : null,
                        bookId: bookId,
                      )),
                    );
                  },
                ),
                data: (cards) => ProgressView(
                  key: ValueKey(key),
                  cards: cards,
                  language: language,
                  preferenceKey: key,
                  initialGroup: initialGroup,
                  isBook: bookId != null,
                ),
              );
        },
      ),
    );
  }
}

/// Presentation also accepts a clock for deterministic reports and layout tests.
class ProgressView extends StatefulWidget {
  const ProgressView({
    super.key,
    required this.cards,
    required this.language,
    required this.preferenceKey,
    this.initialGroup,
    this.now,
    this.isBook = false,
  });
  final List<StudyCard> cards;
  final String language, preferenceKey;
  final LanguageGroup? initialGroup;
  final DateTime? now;
  final bool isBook;
  @override
  State<ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<ProgressView> {
  LanguageGroup? group;
  StudyCue? direction;
  int target = 80;
  String period = '30';
  ProgressInterval interval = ProgressInterval.day;
  DateTimeRange? custom;
  bool changed = false;
  int? selected;
  int? selectedRecalls;
  Future<void> _writes = Future.value();
  List<StudyCard>? _cachedCards;
  String? _cachedQuery;
  ProgressAnalysis? _cachedAnalysis;

  @override
  void initState() {
    super.initState();
    group = widget.initialGroup;
    if (widget.isBook) direction = StudyCue.fromLanguage;
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(widget.preferenceKey);
      if (raw == null || !mounted || changed) return;
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        target = ((saved['target'] as num?)?.toInt() ?? 80).clamp(0, 100);
        interval =
            ProgressInterval.values
                .where((v) => v.name == saved['interval'])
                .firstOrNull ??
            ProgressInterval.day;
        direction = StudyCue.activeDirections
            .where((c) => c.storageKey == saved['direction'])
            .firstOrNull;
        if (widget.isBook) direction = StudyCue.fromLanguage;
        period = ['7', '30', 'all', 'custom'].contains(saved['period'])
            ? saved['period']
            : '30';
        final start = DateTime.tryParse(saved['start'] ?? '');
        final end = DateTime.tryParse(saved['end'] ?? '');
        if (start != null && end != null && !end.isBefore(start)) {
          custom = DateTimeRange(start: start, end: end);
        }
        if (period == 'custom' && custom == null) period = '30';
        if (widget.initialGroup == null && saved['category'] is String) {
          group = LanguageGroup(
            saved['category'],
            tagSystem: saved['tagSystem'] ?? 'Category',
            path: (saved['path'] as List?)?.cast<String>(),
          );
        }
      });
    } catch (_) {
      /* Ignore obsolete preferences; histories are untouched. */
    }
  }

  void _change(VoidCallback update) {
    setState(() {
      changed = true;
      update();
      selected = null;
      selectedRecalls = null;
    });
    final raw = jsonEncode({
      'target': target,
      'direction': direction?.storageKey,
      'period': period,
      'interval': interval.name,
      'start': custom?.start.toIso8601String(),
      'end': custom?.end.toIso8601String(),
      'category': group?.name,
      'tagSystem': group?.tagSystem,
      'path': group?.path,
    });
    // Serialize writes so rapid filter changes cannot persist an older value.
    _writes = _writes
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(widget.preferenceKey, raw);
        })
        .catchError((Object _) {});
  }

  String get groupLabel => group == null
      ? 'All categories'
      : group!.tagSystem == 'Collection'
      ? 'Collection · ${group!.name}'
      : (group!.path ?? [group!.name]).join(' › ');
  String directionLabel(StudyCue? cue) => cue?.label ?? 'All three';
  String get periodLabel => switch (period) {
    '7' => 'Last 7 days',
    '30' => 'Last 30 days',
    'all' => 'All time',
    _ => '${progressDate(custom!.start)} – ${progressDate(custom!.end)}',
  };

  Future<void> _chooseCategory() async {
    List<LanguageGroup> descendants(List<String> parent) => [
      for (final g in languageGroups(widget.cards, parent: parent)) ...[
        g,
        ...descendants(g.path!),
      ],
    ];
    final groups = [
      ...descendants([]),
      ...languageGroups(widget.cards, tagSystem: 'Collection'),
    ];
    final choice = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Category',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Parent categories include all subcategories.'),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('All categories'),
                    selected: group == null,
                    onTap: () => Navigator.pop(context, -1),
                  ),
                  for (var i = 0; i < groups.length; i++)
                    ListTile(
                      leading: Icon(
                        groups[i].tagSystem == 'Collection'
                            ? Icons.collections_bookmark_outlined
                            : Icons.folder_outlined,
                      ),
                      title: Text(
                        groups[i].tagSystem == 'Collection'
                            ? 'Collection · ${groups[i].name}'
                            : (groups[i].path ?? [groups[i].name]).join(' › '),
                      ),
                      onTap: () => Navigator.pop(context, i),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (choice != null && mounted) {
      _change(() => group = choice < 0 ? null : groups[choice]);
    }
  }

  Future<void> _chooseTarget() async {
    var input = '$target';
    final form = GlobalKey<FormState>();
    final choice = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Target score'),
        content: Form(
          key: form,
          child: TextFormField(
            key: const ValueKey('target-input'),
            initialValue: input,
            onChanged: (value) => input = value,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'At least',
              suffixText: '%',
              helperText: 'Whole number from 0 to 100',
            ),
            validator: (value) {
              final n = int.tryParse(value ?? '');
              return n == null || n < 0 || n > 100
                  ? 'Enter a number from 0 to 100.'
                  : null;
            },
            onFieldSubmitted: (_) {
              if (form.currentState!.validate()) {
                Navigator.pop(context, int.parse(input));
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, int.parse(input));
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (choice != null && mounted) _change(() => target = choice);
  }

  Future<void> _choosePeriod(String? value) async {
    if (value == null) return;
    if (value != 'custom') {
      _change(() => period = value);
      return;
    }
    final now = widget.now ?? DateTime.now();
    final dates =
        widget.cards
            .expand((c) => c.reviewHistory.values.expand((r) => r))
            .map((r) => progressDay(r.reviewedAt))
            .toList()
          ..sort();
    final earliest = dates.isEmpty || dates.first.isAfter(now)
        ? progressDay(now)
        : dates.first;
    final initial =
        custom != null &&
            !custom!.start.isBefore(earliest) &&
            !custom!.end.isAfter(now)
        ? custom
        : null;
    final range = await showDateRangePicker(
      context: context,
      firstDate: earliest,
      lastDate: progressDay(now),
      initialDateRange: initial,
    );
    if (range != null && mounted) {
      _change(() {
        custom = range;
        period = 'custom';
      });
    }
  }

  Future<void> _chooseDirection() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Recall type',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final cue in <StudyCue?>[null, ...StudyCue.activeDirections])
              ListTile(
                title: Text(directionLabel(cue)),
                trailing: cue == direction ? const Icon(Icons.check) : null,
                onTap: () =>
                    Navigator.pop(context, cue?.storageKey ?? 'average'),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (value != null && mounted) {
      _change(
        () => direction = StudyCue.activeDirections
            .where((c) => c.storageKey == value)
            .firstOrNull,
      );
    }
  }

  Future<void> _targetMenu() async {
    final value = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Target score',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final n in [50, 80, 90])
              ListTile(
                title: Text('At least $n%'),
                trailing: n == target ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, n),
              ),
            ListTile(
              key: const ValueKey('custom-target'),
              title: const Text('Custom percentage'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, -1),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (!mounted || value == null) return;
    if (value < 0) {
      await _chooseTarget();
    } else {
      _change(() => target = value);
    }
  }

  Future<void> _periodMenu() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Period',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final entry in {
              '7': 'Last 7 days',
              '30': 'Last 30 days',
              'all': 'All time',
              'custom': 'Custom dates',
            }.entries)
              ListTile(
                title: Text(entry.value),
                trailing: entry.key == period ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, entry.key),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (mounted && value != null) await _choosePeriod(value);
  }

  Widget _filter(String label, String value, String key, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '$label: $value',
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey(key),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.expand_more,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterBar(double availableWidth, bool largeText) {
    final columns = largeText
        ? 1
        : availableWidth >= 760
        ? (widget.isBook ? 3 : 4)
        : 2;
    final width = (availableWidth - (columns - 1) * 10) / columns;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: width,
          child: _filter(
            'Category',
            groupLabel,
            'progress-category',
            _chooseCategory,
          ),
        ),
        if (!widget.isBook)
          SizedBox(
            width: width,
            child: _filter(
              'Recall type',
              directionLabel(direction),
              'progress-direction',
              _chooseDirection,
            ),
          ),
        SizedBox(
          width: width,
          child: _filter(
            'Target',
            'At least $target%',
            'progress-target',
            _targetMenu,
          ),
        ),
        SizedBox(
          width: width,
          child: _filter('Period', periodLabel, 'progress-period', _periodMenu),
        ),
      ],
    );
  }

  ProgressAnalysis _analysis(DateTime now) {
    final query = jsonEncode([
      groupLabel,
      group?.tagSystem,
      target,
      direction?.storageKey,
      period,
      custom?.start.toIso8601String(),
      custom?.end.toIso8601String(),
      progressDay(now).toIso8601String(),
    ]);
    if (identical(_cachedCards, widget.cards) && query == _cachedQuery) {
      return _cachedAnalysis!;
    }
    final start = period == 'all'
        ? null
        : period == 'custom'
        ? custom!.start
        : DateTime(now.year, now.month, now.day - int.parse(period) + 1);
    _cachedCards = widget.cards;
    _cachedQuery = query;
    return _cachedAnalysis = analyzeProgress(
      cards: widget.cards.where((c) => group?.contains(c) ?? true).toList(),
      directions: direction == null
          ? StudyCue.activeDirections.toSet()
          : {direction!},
      targetPercent: target,
      now: now,
      start: start,
      end: period == 'custom' ? custom!.end : null,
    );
  }

  String signedChange(int value) => value > 0 ? '+$value' : '$value';
  String bucketLabel(ProgressBucket bucket) {
    if (interval == ProgressInterval.day) return progressDate(bucket.date);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (interval == ProgressInterval.month) {
      return '${months[bucket.start.month - 1]} ${bucket.start.year}';
    }
    return '${months[bucket.start.month - 1]} ${bucket.start.day} – ${months[bucket.date.month - 1]} ${bucket.date.day}';
  }

  Widget _breakdown(List<ProgressBucket> buckets) {
    final theme = Theme.of(context);
    Widget cell(String text, {bool numeric = false, bool heading = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Text(
            text,
            textAlign: numeric ? TextAlign.end : TextAlign.start,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: heading ? FontWeight.w600 : null,
              color: heading ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
          3: FlexColumnWidth(),
        },
        border: TableBorder(
          horizontalInside: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        children: [
          TableRow(
            children: [
              cell('Period', heading: true),
              cell('Cards', numeric: true, heading: true),
              cell('Net change', numeric: true, heading: true),
              cell('Recalls', numeric: true, heading: true),
            ],
          ),
          for (final bucket in buckets.reversed)
            TableRow(
              children: [
                cell(
                  '${bucketLabel(bucket)}${bucket.partial ? ' · Partial' : ''}',
                ),
                cell('${bucket.atTarget}', numeric: true),
                cell(signedChange(bucket.change), numeric: true),
                cell('${bucket.recalls}', numeric: true),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final report = _analysis(now);
    final buckets = groupProgress(report, interval, now);
    final index = (selected ?? buckets.length - 1).clamp(0, buckets.length - 1);
    final recallIndex = (selectedRecalls ?? buckets.length - 1).clamp(
      0,
      buckets.length - 1,
    );
    final last = report.days.last;
    final historical = progressDay(now).isAfter(last.date);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
        final padding = constraints.maxWidth >= 720 ? 28.0 : 16.0;
        return SingleChildScrollView(
          key: const ValueKey('progress-scroll'),
          padding: EdgeInsets.all(padding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: LayoutBuilder(
                builder: (context, inner) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _filterBar(inner.maxWidth, largeText),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SegmentedButton<ProgressInterval>(
                        key: const ValueKey('progress-interval'),
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ProgressInterval.day,
                            label: Text('Day'),
                          ),
                          ButtonSegment(
                            value: ProgressInterval.week,
                            label: Text('Week'),
                          ),
                          ButtonSegment(
                            value: ProgressInterval.month,
                            label: Text('Month'),
                          ),
                        ],
                        selected: {interval},
                        onSelectionChanged: (value) =>
                            _change(() => interval = value.first),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Learning progress',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        Text(
                          '${last.atTarget}',
                          key: const ValueKey('progress-total'),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1.5,
                          ),
                        ),
                        Text(
                          'cards at $target% or higher',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      historical
                          ? 'As of ${progressDate(last.date)}'
                          : 'As of today',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    if (report.medianDays != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Typical time to target · ${report.medianDays!.toStringAsFixed(1)} days',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ),
                    if (report.firstReview == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text(
                          'No recalls yet for this group and recall type.',
                        ),
                      ),
                    const SizedBox(height: 16),
                    ProgressChart(
                      days: buckets,
                      selected: index,
                      bucketLabel: bucketLabel,
                      onSelected: (value) => setState(() => selected = value),
                    ),
                    const SizedBox(height: 32),
                    Divider(color: theme.colorScheme.outlineVariant),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          '${switch (interval) {
                            ProgressInterval.day => 'Daily',
                            ProgressInterval.week => 'Weekly',
                            ProgressInterval.month => 'Monthly',
                          }} recalls',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          '${report.recalls} in this period',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ProgressChart(
                      days: buckets,
                      selected: recallIndex,
                      activity: true,
                      bucketLabel: bucketLabel,
                      onSelected: (value) =>
                          setState(() => selectedRecalls = value),
                    ),
                    if (interval != ProgressInterval.day) _breakdown(buckets),
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Text(
                        'Local time · Today is partial',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
