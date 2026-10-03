import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/card_list/learning_cards.dart';
import 'package:nx_cards/scheduling/language_direction.dart';
import 'package:nx_cards/scheduling/retention.dart';

class CurrentCardsTab extends ConsumerStatefulWidget {
  const CurrentCardsTab({
    super.key,
    required this.cards,
    required this.dashboard,
    this.language,
  });
  final List<StudyCard> cards;
  final CardsDashboard dashboard;
  final String? language;
  @override
  ConsumerState<CurrentCardsTab> createState() => _CurrentCardsTabState();
}

class _CurrentCardsTabState extends ConsumerState<CurrentCardsTab> {
  double maximum = .8;
  double minimum = 0;
  bool weakOnly = true;
  bool expanded = false;
  bool changed = false;
  String get preferenceKey =>
      'current_filters.v1.${widget.language ?? 'books'}';

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted || changed) return;
      final raw = preferences.getString(preferenceKey);
      if (raw == null) return;
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      final directions = StudyCue.activeDirections
          .where(
            (cue) => (saved['directions'] as List).contains(cue.storageKey),
          )
          .toSet();
      final maxValue = (saved['maximum'] as num).toDouble().clamp(0.0, 1.0);
      final minValue = (saved['minimum'] as num).toDouble().clamp(
        0.0,
        maxValue,
      );
      if (directions.isEmpty) return;
      // Restoring a cached Future can complete during route construction.
      // Publish shared state only once the current frame has finished.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || changed) return;
      ref.read(selectedDirectionsProvider(widget.language).notifier).state =
          directions;
      setState(() {
        maximum = maxValue;
        minimum = minValue;
        weakOnly = saved['weakOnly'] == true;
      });
    } catch (_) {
      // Ignore obsolete or malformed preferences.
    }
  }

  void _change(VoidCallback change) {
    setState(() {
      changed = true;
      change();
    });
    final value = jsonEncode({
      'maximum': maximum,
      'minimum': minimum,
      'weakOnly': weakOnly,
      'directions': [
        for (final cue in ref.read(selectedDirectionsProvider(widget.language)))
          cue.storageKey,
      ],
    });
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setString(preferenceKey, value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final directions = ref.watch(selectedDirectionsProvider(widget.language));
    final cards = retentionCards(
      widget.cards,
      directions,
      minimum: minimum,
      maximum: maximum,
      weakOnly: weakOnly,
    );
    final range = weakOnly
        ? 'Below 80%'
        : '${(minimum * 100).round()}–${(maximum * 100).round()}%';
    final summary = '${weakOnly ? 'Weak' : range} (${cards.length}) · ';
    final target = compactLanguageLabel(widget.language ?? '');
    final directionSpans = <InlineSpan>[];
    if (directions.length == 3) {
      directionSpans.add(const TextSpan(text: 'All directions'));
    } else {
      for (final cue in StudyCue.activeDirections.where(directions.contains)) {
        if (directionSpans.isNotEmpty) {
          directionSpans.add(const TextSpan(text: ', '));
        }
        if (cue == StudyCue.fromAudio) {
          directionSpans.add(
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(Icons.volume_up_outlined, size: 14),
            ),
          );
          directionSpans.add(TextSpan(text: ' → $target'));
        } else {
          directionSpans.add(
            TextSpan(
              text: cue == StudyCue.fromLanguage
                  ? 'EN → $target'
                  : '$target → EN',
            ),
          );
        }
      }
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('current-filter-toggle'),
              onPressed: () => setState(() => expanded = !expanded),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text.rich(
                      TextSpan(text: summary, children: directionSpans),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fronts = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Front',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        DirectionChoices(
                          language: widget.language ?? '',
                          selected: directions,
                          onChanged: (value) => _change(
                            () =>
                                ref
                                        .read(
                                          selectedDirectionsProvider(
                                            widget.language,
                                          ).notifier,
                                        )
                                        .state =
                                    value,
                          ),
                        ),
                      ],
                    );
                    final retention = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Retention · $range (${cards.length})',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Slider(
                                key: const ValueKey('current-retention'),
                                value: maximum,
                                divisions: 100,
                                onChanged: (value) => _change(() {
                                  maximum = value;
                                  minimum = 0;
                                  weakOnly = false;
                                }),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _change(() {
                                minimum = 0;
                                maximum = .8;
                                weakOnly = true;
                              }),
                              child: const Text('Weak'),
                            ),
                            TextButton(
                              onPressed: () => _change(() {
                                minimum = .8;
                                maximum = 1;
                                weakOnly = false;
                              }),
                              child: const Text('Strong'),
                            ),
                          ],
                        ),
                      ],
                    );
                    if (widget.language == null) return retention;
                    if (constraints.maxWidth < 720) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          fronts,
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Divider(
                              height: 1,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          retention,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        fronts,
                        SizedBox(
                          height: 64,
                          width: 48,
                          child: VerticalDivider(
                            thickness: 1,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        Expanded(child: retention),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        Expanded(
          child: LearningCardsTab(
            cards: cards,
            dashboard: widget.dashboard,
            showScheduleStatus: true,
            scoreDirections: directions,
            emptyText: 'No cards match this retention range.',
          ),
        ),
      ],
    );
  }
}
