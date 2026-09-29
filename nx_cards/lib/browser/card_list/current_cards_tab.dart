import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  double maximum = 1;
  double minimum = 0;
  bool weakOnly = false;
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.language != null)
                    DirectionChoices(
                      language: widget.language!,
                      selected: directions,
                      onChanged: (value) =>
                          ref
                                  .read(
                                    selectedDirectionsProvider(
                                      widget.language,
                                    ).notifier,
                                  )
                                  .state =
                              value,
                    ),
                  Text(
                    'Retention ${(minimum * 100).round()}–${(maximum * 100).round()}%',
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          key: const ValueKey('current-retention'),
                          value: maximum,
                          divisions: 100,
                          onChanged: (value) => setState(() {
                            maximum = value;
                            minimum = 0;
                            weakOnly = false;
                          }),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          minimum = 0;
                          maximum = .8;
                          weakOnly = true;
                        }),
                        child: const Text('Weak'),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          minimum = .8;
                          maximum = 1;
                          weakOnly = false;
                        }),
                        child: const Text('Strong'),
                      ),
                    ],
                  ),
                ],
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
