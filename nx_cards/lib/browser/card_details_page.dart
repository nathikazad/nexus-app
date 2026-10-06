import 'package:nx_cards/browser/language/similar_sounds_page.dart';
import 'package:nx_cards/study/language/similar_sounds.dart';
import 'package:nx_cards/scheduling/retention.dart';
import 'package:nx_cards/scheduling/language_direction.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/study/language/language_audio_controls.dart';
import 'package:nx_cards/study/language/language_examples.dart';

import 'package:nx_cards/browser/card_edit_dialog.dart';

enum CardDetailsTab { examples, stats, similar }

class CardDetailsPage extends ConsumerStatefulWidget {
  const CardDetailsPage({
    super.key,
    required this.card,
    this.allowEdit = true,
    this.initialTab = CardDetailsTab.examples,
  });

  final StudyCard card;
  final bool allowEdit;
  final CardDetailsTab initialTab;

  @override
  ConsumerState<CardDetailsPage> createState() => _CardDetailsPageState();
}

class _CardDetailsPageState extends ConsumerState<CardDetailsPage> {
  Set<RecallComponent> _statsComponents = RecallComponent.values.toSet();
  CardContent? _editedContent;
  bool _showNotes = false;
  bool _savingStatus = false;
  LearningStatus? _updatedStatus;
  late CardDetailsTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  Future<void> _changeStatus(StudyCard card, LearningStatus status) async {
    if (_savingStatus || card.learningStatus == status) return;
    setState(() => _savingStatus = true);
    try {
      await ref.read(cardLibraryProvider).setLearningStatus(card, status);
      ref.invalidate(cardBodyProvider(widget.card));
      ref.read(cardsInvalidationProvider)();
      if (mounted) setState(() => _updatedStatus = status);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not move card: $error')));
      }
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }

  Future<void> _changeSpokenOnly(StudyCard card, bool value) async {
    final content = card.content;
    if (_savingStatus || content is! LanguageCardContent) return;
    setState(() => _savingStatus = true);
    try {
      await ref
          .read(cardLibraryProvider)
          .setLearningStatus(card, card.learningStatus, spokenOnly: value);
      ref.invalidate(cardBodyProvider(widget.card));
      ref.read(cardsInvalidationProvider)();
      if (mounted) {
        setState(() => _editedContent = content.copyWith(spokenOnly: value));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update spoken only: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }

  Future<void> _edit(StudyCard card) async {
    final invalidate = ref.read(cardsInvalidationProvider);
    final library = ref.read(cardLibraryProvider);
    final content = await showDialog<CardContent>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CardEditDialog(card: card, library: library),
    );
    if (!mounted || content == null) return;
    setState(() => _editedContent = content);
    invalidate();
  }

  @override
  Widget build(BuildContext context) {
    final body = ref.watch(cardBodyProvider(widget.card));
    if (!body.hasValue) {
      return Scaffold(
        appBar: AppBar(title: const Text('Card details')),
        body: Center(
          child: body.hasError
              ? Text('Could not open card: ${body.error}')
              : const CircularProgressIndicator(),
        ),
      );
    }
    final card = (body.value ?? widget.card).copyWith(
      learningStatus: _updatedStatus,
      content: _editedContent,
    );
    final languageContent = switch (card.content) {
      final LanguageCardContent content => content,
      _ => null,
    };
    final audioRepository = ref.watch(cardAudioRepositoryProvider);
    final audioUrl = languageContent?.audioUrl;
    final availableComponents = [
      RecallComponent.meaning,
      RecallComponent.sound,
      if (!card.spokenOnly) RecallComponent.script,
    ];
    final intersection = _statsComponents.intersection(
      availableComponents.toSet(),
    );
    final components = intersection.isEmpty
        ? availableComponents.toSet()
        : intersection;
    final cues = selectedCues(card, components);
    final reviews = [for (final cue in cues) ...card.reviewHistoryFor(cue)]
      ..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));
    final hasStats = selectionReviews(card, null).isNotEmpty;
    final hasExamples = languageContent?.examples.isNotEmpty == true;
    final similarGroups = languageContent?.similarWordGroups.isNotEmpty == true
        ? similarGroupsForCard(
            card,
            ref
                    .watch(
                      cardsCollectionProvider((
                        language: card.language,
                        bookId: null,
                      )),
                    )
                    .value
                    ?.cards ??
                [card],
          )
        : <SimilarSoundGroup>[];
    final availableTabs = <CardDetailsTab>[
      if (hasExamples) CardDetailsTab.examples,
      if (hasStats) CardDetailsTab.stats,
      if (similarGroups.isNotEmpty) CardDetailsTab.similar,
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
                  onPressed: _savingStatus ? null : () => _edit(card),
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
                    if (card.learningStatus == LearningStatus.recall) ...[
                      const SizedBox(width: 12),
                      _RecallStrengthPill(card: card),
                    ],
                    if (card.suspended)
                      const _StatusPill(
                        label: 'Suspended',
                        icon: Icons.pause_circle_outline,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _CardContent(card: card, languageContent: languageContent),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  key: const ValueKey('card-learning-status'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: card.learningStatus != LearningStatus.future,
                  onChanged: _savingStatus
                      ? null
                      : (active) => _changeStatus(
                          card,
                          active
                              ? LearningStatus.recall
                              : LearningStatus.future,
                        ),
                ),
                if (languageContent != null && widget.allowEdit)
                  SwitchListTile.adaptive(
                    key: const ValueKey('card-spoken-only'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Spoken only'),
                    value: card.spokenOnly,
                    onChanged: _savingStatus
                        ? null
                        : (value) => _changeSpokenOnly(card, value),
                  ),
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
                if (card.notes?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('Notes'),
                      onPressed: () => setState(() => _showNotes = !_showNotes),
                    ),
                  ),
                  if (_showNotes)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        card.notes!,
                        style: const TextStyle(height: 1.5),
                      ),
                    ),
                ],
                if (card.linkedWordIds.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('CONTAINS', style: monoLabel),
                  ...ref
                      .watch(cardsDashboardProvider)
                      .when(
                        loading: () => <Widget>[
                          const LinearProgressIndicator(),
                        ],
                        error: (error, stack) => <Widget>[
                          const Text('Could not load linked words'),
                        ],
                        data: (dashboard) {
                          final words =
                              (dashboard.cards
                                  .where(
                                    (word) =>
                                        card.linkedWordIds.contains(word.id),
                                  )
                                  .toList()
                                ..sort(
                                  (a, b) => card.back
                                      .indexOf(a.back)
                                      .compareTo(card.back.indexOf(b.back)),
                                ));
                          return <Widget>[
                            for (final word in words)
                              ListTile(
                                title: Row(
                                  children: [
                                    Flexible(child: Text(word.back)),
                                    if (word.content
                                        case final LanguageCardContent content
                                        when content.audioUrl?.isNotEmpty ==
                                                true &&
                                            audioRepository != null) ...[
                                      const SizedBox(width: 8),
                                      PronunciationButton(
                                        key: ValueKey(
                                          'contains-audio-${word.id}',
                                        ),
                                        audioUrl: content.audioUrl!,
                                        repository: audioRepository,
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  '${word.content is LanguageCardContent ? (word.content as LanguageCardContent).transliteration : ''} — ${word.front}',
                                ),
                                trailing: const Icon(Icons.arrow_forward),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => CardDetailsPage(
                                      card: word,
                                      allowEdit: false,
                                    ),
                                  ),
                                ),
                              ),
                          ];
                        },
                      ),
                ],
                if (visibleTab != null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 26),
                    child: Divider(),
                  ),
                  if (availableTabs.length > 1)
                    SegmentedButton<CardDetailsTab>(
                      style: const ButtonStyle(
                        padding: WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      segments: [
                        if (hasExamples)
                          ButtonSegment(
                            value: CardDetailsTab.examples,
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Examples (${languageContent!.examples.length})',
                                maxLines: 1,
                              ),
                            ),
                            icon: const Icon(Icons.menu_book_outlined),
                          ),
                        if (hasStats)
                          const ButtonSegment(
                            value: CardDetailsTab.stats,
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Stats', maxLines: 1),
                            ),
                            icon: Icon(Icons.insights_outlined),
                          ),
                        if (similarGroups.isNotEmpty)
                          const ButtonSegment(
                            value: CardDetailsTab.similar,
                            label: Text('Similar'),
                          ),
                      ],
                      selected: {visibleTab},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) =>
                          setState(() => _selectedTab = selection.single),
                    ),
                  const SizedBox(height: 20),
                  if (visibleTab == CardDetailsTab.stats) ...[
                    if (card.isLanguageCard) ...[
                      DirectionChoices(
                        key: const ValueKey('stats-components'),
                        language: card.language ?? '',
                        allowed: availableComponents,
                        retentionPercentages: {
                          for (final component in availableComponents)
                            component: recallScore(card, component).percentage,
                        },
                        selected: components,
                        onChanged: (value) =>
                            setState(() => _statsComponents = value),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${cues.length} directions · To or from selected skills',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: RecallColors.muted,
                        ),
                      ),
                    ] else
                      const Text(
                        'Front / Back',
                        style: TextStyle(color: RecallColors.muted),
                      ),
                    const SizedBox(height: 16),
                    _RecallSummary(
                      card: card,
                      components: components,
                      cues: cues,
                      reviews: reviews,
                    ),
                    const SizedBox(height: 24),
                    if (reviews.isEmpty)
                      const Text(
                        'No reviews for these skills yet.',
                        style: TextStyle(color: RecallColors.muted),
                      )
                    else
                      _ReviewHistory(reviews: reviews),
                  ] else if (visibleTab == CardDetailsTab.similar)
                    SimilarWordGroups(groups: similarGroups)
                  else if (languageContent != null)
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

class _RecallStrengthPill extends ConsumerWidget {
  const _RecallStrengthPill({required this.card});

  final StudyCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final average = averageRetention(card, RecallComponent.values);
    final strong = average >= .8;
    final percentage = (average * 100).round();
    return Container(
      key: const ValueKey('card-detail-recall-strength'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: strong ? const Color(0xffecfdf5) : const Color(0xfffff1f2),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '$percentage% retention',
        maxLines: 1,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: strong ? RecallColors.emerald : RecallColors.rose,
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
  Widget build(BuildContext context) {
    final palette = RecallPalette.of(context);
    return DecoratedBox(
      key: const ValueKey('card-content'),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
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

class _RecallSummary extends ConsumerWidget {
  const _RecallSummary({
    required this.card,
    required this.components,
    required this.cues,
    required this.reviews,
  });

  final StudyCard card;
  final Set<RecallComponent> components;
  final Set<StudyCue> cues;
  final List<CardReview> reviews;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = cues.map(card.scheduleFor).toList();
    final dueDates = schedules.map((s) => s.dueAt).nonNulls.toList()..sort();
    final reviewDates = schedules.map((s) => s.lastReviewedAt).nonNulls.toList()
      ..sort();
    final now = DateTime.now().toUtc();
    final successes = reviews.where((review) => review.rating >= 3).length;
    final failures = reviews.length - successes;
    final rate = reviews.isEmpty
        ? 0
        : (successes / reviews.length * 100).round();
    final streak = _successStreak(reviews);
    final score = combinedRecallScore(card, components);
    final stage = switch (card.learningStatus) {
      LearningStatus.future => LearningStage.future,
      LearningStatus.practice => LearningStage.upcoming,
      LearningStatus.recall =>
        score.strong ? LearningStage.past : LearningStage.current,
    };
    final due = dueDates.firstOrNull;
    final skillCount = components
        .where((c) => !card.spokenOnly || c != RecallComponent.script)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KnowledgeBanner(
          status: stage.label,
          progress: null,
          metricValue: '${score.percentage}%',
          metricLabel: card.isLanguageCard
              ? 'Average of $skillCount ${skillCount == 1 ? 'skill' : 'skills'}'
              : '${score.recalled}/5 · ${score.attempts} recent attempts',
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
                    value: _relativeDate(reviewDates.lastOrNull, now),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _StatTile(
                    label: 'Next due',
                    value: stage == LearningStage.past
                        ? _relativeDue(due, now)
                        : 'Available now',
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
                    detail:
                        '${schedules.fold(0, (sum, s) => sum + s.lapseCount)} lapses',
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
          Expanded(
            flex: 2,
            child: Column(
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
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ],
            ),
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
  Widget build(BuildContext context) {
    final palette = RecallPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.line),
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
    final palette = RecallPalette.of(context);
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
            color: palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.line),
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
                              palette: palette,
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
    required this.palette,
  });

  static const height = 126.0;
  static const _padding = 18.0;
  static const _step = 48.0;
  static const yesY = 12.0;
  static const noY = 82.0;
  static const _dateY = 101.0;

  final List<CardReview> reviews;
  final int selectedIndex;
  final RecallPalette palette;

  static double widthFor(int count) =>
      count <= 1 ? 64 : _padding * 2 + (count - 1) * _step;

  static int indexForX(double x, int count) =>
      ((x - _padding) / _step).round().clamp(0, count - 1);

  @override
  void paint(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = palette.line
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
        ..color = palette.faint
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
            ..color = palette.soft
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawCircle(
        point,
        5.5,
        Paint()
          ..color = success ? palette.ink : palette.surface
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        point,
        5.5,
        Paint()
          ..color = palette.ink
          ..strokeWidth = index == selectedIndex ? 2 : 1.4
          ..style = PaintingStyle.stroke,
      );

      final reviewedAt = reviews[index].reviewedAt.toLocal();
      final dateLabel = TextPainter(
        text: TextSpan(
          text: _monthDay(reviewedAt),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 8,
            color: palette.faint,
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
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.palette != palette;
}

class _SelectedReview extends StatelessWidget {
  const _SelectedReview({required this.review});

  final CardReview review;

  @override
  Widget build(BuildContext context) {
    final success = review.rating >= 3;
    final palette = RecallPalette.of(context);
    final elapsed = Duration(seconds: review.elapsedSeconds);
    final next = Duration(seconds: review.scheduledSeconds);
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: success ? palette.ink : palette.soft,
            shape: BoxShape.circle,
            border: success ? null : Border.all(color: palette.line),
          ),
          child: Text(
            success ? 'Y' : 'N',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: success ? palette.background : palette.muted,
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
  Widget build(BuildContext context) {
    final palette = RecallPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _PlainField(label: label, value: value),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = RecallPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: palette.faint),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: palette.muted)),
        ],
      ),
    );
  }
}

String _cardSource(StudyCard card) =>
    card.sourceBookName ?? card.language ?? 'Flashcard';

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

int _successStreak(List<CardReview> reviews) {
  var streak = 0;
  for (final review in reviews.reversed) {
    if (review.rating < 3) break;
    streak++;
  }
  return streak;
}
