import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/journal/journal_service.dart';
import 'package:nx_docs/library/library_providers.dart';
import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:nx_docs/workspace/workspace_providers.dart';

enum _CalendarLevel { days, months, years }

class JournalCalendar extends ConsumerStatefulWidget {
  const JournalCalendar({required this.onOpen, super.key});
  final ValueChanged<int> onOpen;

  @override
  ConsumerState<JournalCalendar> createState() => _JournalCalendarState();
}

class _JournalCalendarState extends ConsumerState<JournalCalendar> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selected;
  _CalendarLevel _level = _CalendarLevel.days;
  bool _opening = false;
  bool _refreshFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() async {
    final workspace = ref.read(documentWorkspaceProvider);
    try {
      await ref.read(journalServiceProvider)?.refresh(force: true);
      if (mounted &&
          identical(workspace, ref.read(documentWorkspaceProvider))) {
        setState(() => _refreshFailed = false);
      }
    } catch (_) {
      if (mounted &&
          identical(workspace, ref.read(documentWorkspaceProvider))) {
        setState(() => _refreshFailed = true);
      }
    }
  }

  Future<void> _open(DateTime date) async {
    if (_opening) return;
    final service = ref.read(journalServiceProvider);
    if (service == null) return;
    setState(() {
      _opening = true;
      _selected = date;
    });
    try {
      final document = await service.openDate(
        date,
        title: MaterialLocalizations.of(context).formatFullDate(date),
      );
      if (!mounted || !identical(service, ref.read(journalServiceProvider))) {
        return;
      }
      widget.onOpen(document.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open this journal entry. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _move(int direction) => setState(() {
    _month = switch (_level) {
      _CalendarLevel.days => DateTime(_month.year, _month.month + direction),
      _CalendarLevel.months => DateTime(_month.year + direction, _month.month),
      _CalendarLevel.years => DateTime(
        _month.year + 12 * direction,
        _month.month,
      ),
    };
  });

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(catalogStateProvider(const CatalogQuery.all()));
    // The async identity check prevents navigation after a domain switch.
    ref.watch(journalServiceProvider);
    final entries = <String>{
      for (final entry in data.value?.items ?? <DocumentSummary>[])
        if (entry.isJournalEntry && entry.journalDate != null)
          journalDateKey(entry.journalDate!),
    };
    final localizations = MaterialLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final yearStart = (_month.year ~/ 12) * 12;
    final heading = switch (_level) {
      _CalendarLevel.days => localizations.formatMonthYear(_month),
      _CalendarLevel.months => '${_month.year}',
      _CalendarLevel.years => '$yearStart–${yearStart + 11}',
    };
    final error = _refreshFailed || data.hasError || data.value?.error != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous',
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: TextButton(
                  key: const Key('journal-calendar-heading'),
                  onPressed: () => setState(() {
                    _level = switch (_level) {
                      _CalendarLevel.days => _CalendarLevel.months,
                      _CalendarLevel.months => _CalendarLevel.years,
                      _CalendarLevel.years => _CalendarLevel.days,
                    };
                  }),
                  child: Text(heading, textAlign: TextAlign.center),
                ),
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: () => _move(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          if (data.isLoading ||
              data.value?.isInitialLoading == true ||
              _opening)
            const LinearProgressIndicator(),
          if (error) ...[
            const Text('Calendar entries could not be loaded.'),
            TextButton(onPressed: _refresh, child: const Text('Retry')),
          ],
          if (_level == _CalendarLevel.days) ...[
            Row(
              children: List.generate(
                7,
                (index) => Expanded(
                  child: Center(
                    child: Text(
                      localizations.narrowWeekdays[(index +
                              localizations.firstDayOfWeekIndex) %
                          7],
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _days(
              entries,
              localizations,
              colors,
              !data.isLoading && data.value?.isInitialLoading == false,
            ),
          ] else
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.3,
              children: List.generate(12, (index) {
                final date = _level == _CalendarLevel.months
                    ? DateTime(_month.year, index + 1)
                    : DateTime(yearStart + index);
                final prefix = _level == _CalendarLevel.months
                    ? journalDateKey(date).substring(0, 7)
                    : '${date.year}-';
                final hasEntry = entries.any((key) => key.startsWith(prefix));
                return TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                  ),
                  onPressed: () => setState(() {
                    _month = date;
                    _level = _level == _CalendarLevel.years
                        ? _CalendarLevel.months
                        : _CalendarLevel.days;
                  }),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _level == _CalendarLevel.months
                            ? DateFormat.MMM(
                                Localizations.localeOf(context).toString(),
                              ).format(date)
                            : '${date.year}',
                      ),
                      if (hasEntry)
                        Icon(Icons.circle, size: 5, color: colors.primary),
                    ],
                  ),
                );
              }),
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, size: 6, color: colors.primary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Journal entry',
                  style: TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  final today = DateTime.now();
                  _month = DateTime(today.year, today.month);
                  _level = _CalendarLevel.days;
                }),
                child: const Text('Today'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _days(
    Set<String> entries,
    MaterialLocalizations labels,
    ColorScheme colors,
    bool ready,
  ) {
    final offset = (_month.weekday % 7 - labels.firstDayOfWeekIndex + 7) % 7;
    final count = DateTime(_month.year, _month.month + 1, 0).day;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 2,
      ),
      itemCount: ((offset + count + 6) ~/ 7) * 7,
      itemBuilder: (context, index) {
        final day = index - offset + 1;
        if (day < 1 || day > count) return const SizedBox.shrink();
        final date = DateTime(_month.year, _month.month, day);
        final hasEntry = entries.contains(journalDateKey(date));
        final today = DateUtils.isSameDay(date, DateTime.now());
        final selected = DateUtils.isSameDay(date, _selected);
        return Semantics(
          label:
              '${labels.formatFullDate(date)}, ${hasEntry ? "journal entry available" : "no journal entry"}',
          button: true,
          selected: selected,
          child: Tooltip(
            message: hasEntry ? 'Open journal entry' : 'Create journal entry',
            child: Material(
              color: selected
                  ? colors.onSurface
                  : hasEntry
                  ? colors.secondaryContainer
                  : Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                key: ValueKey('journal-day-${journalDateKey(date)}'),
                customBorder: const CircleBorder(),
                onTap: _opening || !ready ? null : () => _open(date),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 12,
                        color: selected ? colors.surface : colors.onSurface,
                        fontWeight: hasEntry
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    SizedBox(
                      height: 5,
                      child: today
                          ? Center(
                              child: Container(
                                width: 14,
                                height: 2,
                                color: selected
                                    ? colors.surface
                                    : colors.onSurface,
                              ),
                            )
                          : hasEntry
                          ? Icon(
                              Icons.circle,
                              size: 4,
                              color: selected
                                  ? colors.surface
                                  : colors.onSurface,
                            )
                          : null,
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
