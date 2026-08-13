import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/language/language_audio_controls.dart';
import 'package:nx_cards/study/language/language_examples.dart';

enum CardDetailsTab { stats, examples }

class CardDetailsPage extends ConsumerStatefulWidget {
  const CardDetailsPage({
    super.key,
    required this.card,
    this.allowEdit = true,
    this.initialTab = CardDetailsTab.stats,
  });

  final StudyCard card;
  final bool allowEdit;
  final CardDetailsTab initialTab;

  @override
  ConsumerState<CardDetailsPage> createState() => _CardDetailsPageState();
}

class _CardDetailsPageState extends ConsumerState<CardDetailsPage> {
  StudyCue? _selectedCue;
  late CardDetailsTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  List<StudyCue> get _reviewedCues => [
    for (final cue in StudyCue.values)
      if (widget.card.reviewHistoryFor(cue).isNotEmpty) cue,
  ];

  StudyCue? get _visibleCue {
    final cues = _reviewedCues;
    if (cues.isEmpty) return null;
    if (_selectedCue case final selected? when cues.contains(selected)) {
      return selected;
    }
    return cues.first;
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final languageContent = switch (card.content) {
      final LanguageCardContent content => content,
      _ => null,
    };
    final audioRepository = ref.watch(cardAudioRepositoryProvider);
    final audioUrl = languageContent?.audioUrl;
    final reviewedCues = _reviewedCues;
    final visibleCue = _visibleCue;
    final hasStats = reviewedCues.isNotEmpty;
    final hasExamples = languageContent?.examples.isNotEmpty == true;
    final availableTabs = <CardDetailsTab>[
      if (hasStats) CardDetailsTab.stats,
      if (hasExamples) CardDetailsTab.examples,
    ];
    final visibleTab = availableTabs.contains(_selectedTab)
        ? _selectedTab
        : availableTabs.firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Card details'),
        actions: widget.allowEdit
            ? [
                IconButton(
                  tooltip: 'Edit card',
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.edit_outlined),
                ),
                const SizedBox(width: 6),
              ]
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 48),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _cardSource(card).toUpperCase(),
                        style: monoLabel,
                      ),
                    ),
                    if (card.suspended)
                      const _StatusPill(
                        label: 'Suspended',
                        icon: Icons.pause_circle_outline,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _CardContent(card: card, languageContent: languageContent),
                if (audioUrl?.isNotEmpty == true &&
                    audioRepository != null) ...[
                  const SizedBox(height: 14),
                  LanguageAudioControls(
                    key: ValueKey('${card.id}:details:$audioUrl'),
                    audioUrl: audioUrl!,
                    repository: audioRepository,
                    autoPlay: false,
                  ),
                ],
                if (card.sourceBookName case final sourceBook?) ...[
                  const SizedBox(height: 14),
                  _CardField(label: 'Source book', value: sourceBook),
                ],
                if (visibleTab != null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 26),
                    child: Divider(),
                  ),
                  SegmentedButton<CardDetailsTab>(
                    segments: [
                      if (hasStats)
                        const ButtonSegment(
                          value: CardDetailsTab.stats,
                          label: Text('Stats'),
                          icon: Icon(Icons.insights_outlined),
                        ),
                      if (hasExamples)
                        ButtonSegment(
                          value: CardDetailsTab.examples,
                          label: Text(
                            'Examples (${languageContent!.examples.length})',
                          ),
                          icon: const Icon(Icons.menu_book_outlined),
                        ),
                    ],
                    selected: {visibleTab},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        setState(() => _selectedTab = selection.single),
                  ),
                  const SizedBox(height: 20),
                  if (visibleTab == CardDetailsTab.stats) ...[
                    if (reviewedCues.length == 1)
                      _DirectionHeading(
                        label: _cueLabel(reviewedCues.single, card),
                      )
                    else
                      _DirectionSelector(
                        cues: reviewedCues,
                        selected: visibleCue!,
                        labelFor: (cue) => _cueLabel(cue, card),
                        onSelected: (cue) => setState(() => _selectedCue = cue),
                      ),
                    const SizedBox(height: 16),
                    _RecallSummary(card: card, cue: visibleCue!),
                    const SizedBox(height: 24),
                    _ReviewHistory(reviews: card.reviewHistoryFor(visibleCue)),
                  ] else if (languageContent != null)
                    LanguageExamples(
                      examples: languageContent.examples,
                      audioRepository: audioRepository,
                      audioKeyPrefix: '${card.id}:details-examples',
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({required this.card, required this.languageContent});

  final StudyCard card;
  final LanguageCardContent? languageContent;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: RecallColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: RecallColors.line),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlainField(label: 'Front', value: card.front),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(height: 1),
          ),
          _PlainField(
            label: languageContent == null ? 'Back' : card.language ?? 'Back',
            value: card.back,
            style: languageContent == null
                ? null
                : const TextStyle(
                    fontSize: 28,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
          ),
          if (languageContent != null &&
              languageContent!.transliteration.isNotEmpty) ...[
            const SizedBox(height: 5),
            SelectableText(
              languageContent!.transliteration,
              style: const TextStyle(
                fontSize: 16,
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: RecallColors.faint,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _PlainField extends StatelessWidget {
  const _PlainField({required this.label, required this.value, this.style});

  final String label;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: monoLabel),
      const SizedBox(height: 6),
      SelectableText(
        value,
        style: style ?? const TextStyle(fontSize: 19, height: 1.4),
      ),
    ],
  );
}

class _DirectionHeading extends StatelessWidget {
  const _DirectionHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    key: const ValueKey('single-review-direction'),
    style: const TextStyle(fontSize: 14, color: RecallColors.muted),
  );
}

class _DirectionSelector extends StatelessWidget {
  const _DirectionSelector({
    required this.cues,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  final List<StudyCue> cues;
  final StudyCue selected;
  final String Function(StudyCue cue) labelFor;
  final ValueChanged<StudyCue> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SegmentedButton<StudyCue>(
      key: const ValueKey('review-direction-selector'),
      segments: [
        for (final cue in cues)
          ButtonSegment(value: cue, label: Text(labelFor(cue))),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onSelected(selection.single),
    ),
  );
}

class _RecallSummary extends StatelessWidget {
  const _RecallSummary({required this.card, required this.cue});

  final StudyCard card;
  final StudyCue cue;

  @override
  Widget build(BuildContext context) {
    final schedule = card.scheduleFor(cue);
    final reviews = card.reviewHistoryFor(cue);
    final now = DateTime.now().toUtc();
    final successes = reviews.where((review) => review.rating >= 3).length;
    final failures = reviews.length - successes;
    final rate = reviews.isEmpty
        ? 0
        : (successes / reviews.length * 100).round();
    final streak = _successStreak(reviews);
    final isLearning =
        schedule.schedulingState == 'learning' ||
        schedule.schedulingState == 'relearning';
    final recall = isLearning ? null : _estimatedRecall(schedule, card.id, now);
    final due = schedule.dueAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KnowledgeBanner(
          status: _knowledgeStatus(schedule, now),
          progress: isLearning ? _learningProgress(schedule) : null,
          metricValue: isLearning
              ? '$successes/${reviews.length}'
              : recall == null
              ? null
              : '${(recall * 100).round()}%',
          metricLabel: isLearning ? 'recalled' : 'estimated recall',
          due: due,
          now: now,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 560
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: width,
                  child: _StatTile(
                    label: 'Last reviewed',
                    value: _relativeDate(schedule.lastReviewedAt, now),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _StatTile(
                    label: 'Next due',
                    value: _relativeDue(due, now),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _StatTile(
                    label: 'Recall record',
                    value: '$successes yes · $failures no',
                    detail: '$rate% successful',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _StatTile(
                    label: 'Consistency',
                    value: '$streak current streak',
                    detail: '${schedule.lapseCount} lapses',
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _KnowledgeBanner extends StatelessWidget {
  const _KnowledgeBanner({
    required this.status,
    required this.progress,
    required this.metricValue,
    required this.metricLabel,
    required this.due,
    required this.now,
  });

  final String status;
  final String? progress;
  final String? metricValue;
  final String metricLabel;
  final DateTime? due;
  final DateTime now;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: RecallColors.ink,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CURRENT STATE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  letterSpacing: .8,
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                status,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (progress case final progress?) ...[
                const SizedBox(height: 3),
                Text(progress, style: const TextStyle(color: Colors.white70)),
              ],
              const SizedBox(height: 3),
              Text(
                _relativeDue(due, now),
                style: const TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
        if (metricValue != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                metricValue!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                metricLabel,
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
      ],
    ),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: RecallColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: RecallColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: monoLabel),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        if (detail case final detail?) ...[
          const SizedBox(height: 2),
          Text(
            detail,
            style: const TextStyle(fontSize: 12, color: RecallColors.muted),
          ),
        ],
      ],
    ),
  );
}

class _ReviewHistory extends StatefulWidget {
  const _ReviewHistory({required this.reviews});

  final List<CardReview> reviews;

  @override
  State<_ReviewHistory> createState() => _ReviewHistoryState();
}

class _ReviewHistoryState extends State<_ReviewHistory> {
  late int _selectedIndex = widget.reviews.length - 1;

  @override
  void didUpdateWidget(covariant _ReviewHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reviews != widget.reviews ||
        _selectedIndex >= widget.reviews.length) {
      _selectedIndex = widget.reviews.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviews = widget.reviews;
    final selected = reviews[_selectedIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Review history',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${reviews.length} review${reviews.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, color: RecallColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          key: const ValueKey('review-history-graph'),
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          decoration: BoxDecoration(
            color: RecallColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RecallColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _ReviewGraphPainter.height,
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: Stack(
                        children: [
                          Positioned(
                            top: _ReviewGraphPainter.yesY - 6,
                            left: 0,
                            right: 0,
                            child: const Text(
                              'YES',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: RecallColors.faint,
                              ),
                            ),
                          ),
                          Positioned(
                            top: _ReviewGraphPainter.noY - 6,
                            left: 0,
                            right: 0,
                            child: const Text(
                              'NO',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: RecallColors.faint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) {
                            final index = _ReviewGraphPainter.indexForX(
                              details.localPosition.dx,
                              reviews.length,
                            );
                            setState(() => _selectedIndex = index);
                          },
                          child: CustomPaint(
                            size: Size(
                              _ReviewGraphPainter.widthFor(reviews.length),
                              _ReviewGraphPainter.height,
                            ),
                            painter: _ReviewGraphPainter(
                              reviews: reviews,
                              selectedIndex: _selectedIndex,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'OLDER  →  NEWER',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  letterSpacing: .6,
                  color: RecallColors.faint,
                ),
              ),
              const Divider(height: 22),
              _SelectedReview(review: selected),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewGraphPainter extends CustomPainter {
  const _ReviewGraphPainter({
    required this.reviews,
    required this.selectedIndex,
  });

  static const height = 126.0;
  static const _padding = 18.0;
  static const _step = 48.0;
  static const yesY = 12.0;
  static const noY = 82.0;
  static const _dateY = 101.0;

  final List<CardReview> reviews;
  final int selectedIndex;

  static double widthFor(int count) =>
      count <= 1 ? 64 : _padding * 2 + (count - 1) * _step;

  static int indexForX(double x, int count) =>
      ((x - _padding) / _step).round().clamp(0, count - 1);

  @override
  void paint(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = RecallColors.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, yesY), Offset(size.width, yesY), guide);
    canvas.drawLine(Offset(0, noY), Offset(size.width, noY), guide);

    final path = Path();
    for (var index = 0; index < reviews.length; index++) {
      final point = _point(index);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = RecallColors.faint
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    for (var index = 0; index < reviews.length; index++) {
      final point = _point(index);
      final success = reviews[index].rating >= 3;
      if (index == selectedIndex) {
        canvas.drawCircle(
          point,
          9,
          Paint()
            ..color = RecallColors.soft
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawCircle(
        point,
        5.5,
        Paint()
          ..color = success ? RecallColors.ink : RecallColors.surface
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        point,
        5.5,
        Paint()
          ..color = RecallColors.ink
          ..strokeWidth = index == selectedIndex ? 2 : 1.4
          ..style = PaintingStyle.stroke,
      );

      final reviewedAt = reviews[index].reviewedAt.toLocal();
      final dateLabel = TextPainter(
        text: TextSpan(
          text: _monthDay(reviewedAt),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 8,
            color: RecallColors.faint,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      dateLabel.paint(canvas, Offset(point.dx - dateLabel.width / 2, _dateY));
    }
  }

  Offset _point(int index) =>
      Offset(_padding + index * _step, reviews[index].rating >= 3 ? yesY : noY);

  @override
  bool shouldRepaint(covariant _ReviewGraphPainter oldDelegate) =>
      oldDelegate.reviews != reviews ||
      oldDelegate.selectedIndex != selectedIndex;
}

class _SelectedReview extends StatelessWidget {
  const _SelectedReview({required this.review});

  final CardReview review;

  @override
  Widget build(BuildContext context) {
    final success = review.rating >= 3;
    final elapsed = Duration(seconds: review.elapsedSeconds);
    final next = Duration(seconds: review.scheduledSeconds);
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: success ? RecallColors.ink : RecallColors.soft,
            shape: BoxShape.circle,
            border: success ? null : Border.all(color: RecallColors.line),
          ),
          child: Text(
            success ? 'Y' : 'N',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: success ? Colors.white : RecallColors.muted,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${success ? 'Yes' : 'No'} · ${_calendarDate(review.reviewedAt.toLocal())}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (elapsed > Duration.zero)
                    'After ${_formatInterval(elapsed)}',
                  'next ${_formatInterval(next)}',
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: RecallColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardField extends StatelessWidget {
  const _CardField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: RecallColors.soft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: RecallColors.line),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: _PlainField(label: label, value: value),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: RecallColors.soft,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: RecallColors.faint),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: RecallColors.muted),
        ),
      ],
    ),
  );
}

String _cueLabel(StudyCue cue, StudyCard card) => switch (cue) {
  StudyCue.fromLanguage => 'Front → ${card.language ?? 'Back'}',
  StudyCue.toLanguage => '${card.language ?? 'Back'} → Front',
  StudyCue.transliteration => 'Transliteration → Front',
};

String _cardSource(StudyCard card) =>
    card.sourceBookName ?? card.language ?? card.studyCategory ?? 'Flashcard';

String _knowledgeStatus(CardSchedule schedule, DateTime now) {
  final due = schedule.dueAt;
  if (schedule.lastReviewedAt == null) return 'New';
  if (schedule.schedulingState == 'learning') return 'Learning';
  if (schedule.schedulingState == 'relearning') return 'Relearning';
  if (due != null && !due.isAfter(now)) return 'Due now';
  return 'Retained';
}

String _learningProgress(CardSchedule schedule) {
  final step = (schedule.learningStep ?? 0) + 1;
  if (schedule.schedulingState == 'relearning') {
    return 'Relearning step $step of 1';
  }
  return 'Learning step $step of 2';
}

double? _estimatedRecall(CardSchedule schedule, int cardId, DateTime now) {
  final lastReview = schedule.lastReviewedAt;
  final stability = schedule.stability;
  if (lastReview == null || stability == null || stability <= 0) return null;
  final scheduler = fsrs.Scheduler(desiredRetention: .9, enableFuzzing: false);
  final fsrsCard = fsrs.Card(
    cardId: cardId,
    state: fsrs.State.review,
    stability: stability,
    difficulty: schedule.difficulty,
    due: schedule.dueAt,
    lastReview: lastReview.toUtc(),
  );
  return scheduler.getCardRetrievability(fsrsCard, currentDateTime: now);
}

int _successStreak(List<CardReview> reviews) {
  var streak = 0;
  for (final review in reviews.reversed) {
    if (review.rating < 3) break;
    streak++;
  }
  return streak;
}

String _relativeDate(DateTime? value, DateTime now) {
  if (value == null) return 'Never';
  final elapsed = now.difference(value.toUtc());
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes} min ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours} hr ago';
  if (elapsed.inDays == 1) return 'Yesterday';
  if (elapsed.inDays < 30) return '${elapsed.inDays} days ago';
  return _calendarDate(value.toLocal());
}

String _relativeDue(DateTime? value, DateTime now) {
  if (value == null) return 'Not scheduled';
  final difference = value.toUtc().difference(now);
  if (difference.abs().inMinutes < 1) return 'Due now';
  final absolute = difference.abs();
  final interval = _formatDueInterval(absolute);
  final exactDate = _calendarDate(value.toLocal());
  if (difference.isNegative) {
    return absolute.inHours >= 24
        ? 'Overdue by $interval · due $exactDate'
        : 'Overdue by $interval';
  }
  return absolute.inHours >= 24
      ? 'Due in $interval · $exactDate'
      : 'Due in $interval';
}

String _formatDueInterval(Duration duration) {
  if (duration.inHours < 24) return _formatInterval(duration);
  final days = duration.inHours ~/ 24;
  final hours = duration.inHours.remainder(24);
  return hours == 0 ? '${days}d' : '${days}d ${hours}h';
}

String _formatInterval(Duration duration) {
  if (duration.inMinutes < 1) return '< 1 min';
  if (duration.inMinutes < 60) return '${duration.inMinutes} min';
  if (duration.inHours < 24) return '${duration.inHours} hr';
  if (duration.inDays < 30) return '${duration.inDays} days';
  final months = (duration.inDays / 30).round();
  if (months < 12) return '$months mo';
  final years = duration.inDays / 365;
  return '${years.toStringAsFixed(years >= 10 ? 0 : 1)} yr';
}

String _calendarDate(DateTime value) {
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
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

String _monthDay(DateTime value) =>
    '${value.month.toString().padLeft(2, '0')}/'
    '${value.day.toString().padLeft(2, '0')}';
