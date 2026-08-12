import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/settings/review_progression_settings.dart';
import 'package:nx_cards/features/shell/word_schedule_status.dart';
import 'package:nx_cards/features/study/language_study_page.dart';
import 'package:nx_cards/features/study/language_fast_recall_page.dart';
import 'package:nx_cards/features/study/script_draw_practice_page.dart';
import 'package:nx_cards/features/study/script_recall_policy.dart';
import 'package:nx_cards/features/study/study_screen.dart';
import 'package:nx_cards/features/voice_study/voice_study_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StudyOrder { normal, shuffle }

enum StudyMode { study, recall, ai }

enum StudyPresentation { sheet, draw }

enum RecallPresentation { standard, fast }

enum RecallCardState { learning, relearning, retained, newCard }

enum RecallTiming { allMatching, dueNow }

class StudySetupScreen extends ConsumerStatefulWidget {
  const StudySetupScreen({
    super.key,
    required this.title,
    required this.prompts,
    required this.studyCards,
    required this.fromLanguage,
    required this.toLanguage,
    this.preferenceKey,
  });

  final String title;
  final List<StudyPrompt> prompts;
  final List<StudyCard> studyCards;
  final String fromLanguage;
  final String toLanguage;
  final String? preferenceKey;

  @override
  ConsumerState<StudySetupScreen> createState() => _StudySetupScreenState();
}

class _StudySetupScreenState extends ConsumerState<StudySetupScreen> {
  StudyMode _mode = StudyMode.study;
  StudyPresentation _studyPresentation = StudyPresentation.sheet;
  RecallPresentation _recallPresentation = RecallPresentation.standard;
  StudyCue? _cue = StudyCue.fromLanguage;
  final Set<LearningStatus> _learningStatuses = <LearningStatus>{
    LearningStatus.learning,
  };
  final Set<RecallCardState> _recallStates = RecallCardState.values.toSet();
  RecallTiming _recallTiming = RecallTiming.allMatching;
  int _retainedMaxPercentage = 100;
  StudyOrder _order = StudyOrder.normal;
  int _count = 1;
  bool _starting = false;
  int _preferenceRevision = 0;

  String get _storedPreferenceKey =>
      'study_setup.v1.${widget.preferenceKey ?? widget.title}';

  @override
  void initState() {
    super.initState();
    _resetCount();
    unawaited(_restorePreferences());
  }

  Future<void> _restorePreferences() async {
    final revision = _preferenceRevision;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storedPreferenceKey);
    if (raw == null || !mounted || revision != _preferenceRevision) return;
    try {
      final saved = jsonDecode(raw);
      if (saved is! Map<String, dynamic>) return;
      final mode = _enumByName(StudyMode.values, saved['mode']);
      final studyPresentation = _enumByName(
        StudyPresentation.values,
        saved['studyPresentation'],
      );
      final recallPresentation = _enumByName(
        RecallPresentation.values,
        saved['recallPresentation'],
      );
      final cue = _enumByName(StudyCue.values, saved['cue']);
      final order = _enumByName(StudyOrder.values, saved['order']);
      final recallStates = saved['recallStates'] is List
          ? (saved['recallStates'] as List)
                .map((value) => _enumByName(RecallCardState.values, value))
                .whereType<RecallCardState>()
                .toSet()
          : const <RecallCardState>{};
      final recallTiming = _enumByName(
        RecallTiming.values,
        saved['recallTiming'],
      );
      final retainedMaxPercentage = saved['retainedMaxPercentage'];
      final statuses = saved['learningStatuses'] is List
          ? (saved['learningStatuses'] as List)
                .map((value) => _enumByName(LearningStatus.values, value))
                .whereType<LearningStatus>()
                .toSet()
          : const <LearningStatus>{};
      setState(() {
        if (mode != null) _mode = mode;
        if (studyPresentation != null) {
          _studyPresentation = studyPresentation;
        }
        if (recallPresentation != null) {
          _recallPresentation = recallPresentation;
        }
        if (cue != null) _cue = cue;
        if (order != null) _order = order;
        if (statuses.isNotEmpty) {
          _learningStatuses
            ..clear()
            ..addAll(statuses);
        }
        if (recallStates.isNotEmpty) {
          _recallStates
            ..clear()
            ..addAll(recallStates);
        }
        if (recallTiming != null) _recallTiming = recallTiming;
        if (retainedMaxPercentage is int) {
          _retainedMaxPercentage = retainedMaxPercentage.clamp(0, 100);
        }
        if (_mode == StudyMode.recall &&
            _isScriptStudy &&
            !ScriptRecallPolicy.allowedCues.contains(_cue)) {
          _cue = StudyCue.fromLanguage;
        }
        final available = _availableCount;
        final savedCount = saved['count'];
        _count = savedCount is int
            ? savedCount.clamp(1, max(1, available))
            : min(10, max(1, available));
      });
    } on Object {
      // Ignore malformed local preferences and retain the safe defaults.
    }
  }

  void _rememberPreferences() {
    _preferenceRevision += 1;
    unawaited(_savePreferences());
  }

  Future<void> _savePreferences() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storedPreferenceKey,
      jsonEncode(<String, Object?>{
        'mode': _mode.name,
        'studyPresentation': _studyPresentation.name,
        'recallPresentation': _recallPresentation.name,
        'cue': _cue?.name,
        'learningStatuses': [
          for (final status in _learningStatuses) status.name,
        ],
        'recallStates': [for (final state in _recallStates) state.name],
        'recallTiming': _recallTiming.name,
        'retainedMaxPercentage': _retainedMaxPercentage,
        'order': _order.name,
        'count': _count,
      }),
    );
  }

  T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  List<StudyPrompt> get _candidates {
    final cue = _cue;
    if (cue == null) return const <StudyPrompt>[];
    if (_usesRecallFilters) {
      return _recallBaseCandidates
          .where(
            (prompt) =>
                _recallTiming == RecallTiming.allMatching ||
                _isDueForRecall(prompt.card),
          )
          .toList(growable: false);
    }
    return widget.prompts
        .where(
          (prompt) =>
              prompt.cue == cue &&
              _learningStatuses.contains(prompt.card.learningStatus),
        )
        .toList();
  }

  List<StudyPrompt> get _recallBaseCandidates {
    final cue = _cue;
    if (cue == null) return const <StudyPrompt>[];
    return <StudyPrompt>[
      for (final card in widget.studyCards)
        if (!card.suspended &&
            card.scheduleFor(cue).enabled &&
            _matchesRecallBaseFilters(card))
          StudyPrompt(card: card, cue: cue),
    ];
  }

  bool _matchesRecallBaseFilters(StudyCard card) =>
      _learningStatuses.contains(card.learningStatus) &&
      _recallStates.contains(_recallState(card)) &&
      (_recallState(card) != RecallCardState.retained ||
          frontToBackRecallPercentage(
                card,
                historyWindow: _reviewHistoryWindow,
              ) <=
              _retainedMaxPercentage);

  bool _matchesRecallFilters(StudyCard card) =>
      _matchesRecallBaseFilters(card) &&
      (_recallTiming == RecallTiming.allMatching || _isDueForRecall(card));

  bool _isDueForRecall(StudyCard card) =>
      card.scheduleFor(StudyCue.fromLanguage).isDueAt(DateTime.now().toUtc());

  RecallCardState _recallState(StudyCard card) {
    final schedule = card.scheduleFor(StudyCue.fromLanguage);
    if (schedule.lastReviewedAt == null) return RecallCardState.newCard;
    return switch (schedule.schedulingState) {
      'learning' => RecallCardState.learning,
      'relearning' => RecallCardState.relearning,
      _ => RecallCardState.retained,
    };
  }

  List<StudyCard> get _drawCandidates => widget.studyCards
      .where(
        (card) =>
            card.content is LanguageCardContent &&
            !card.suspended &&
            _learningStatuses.contains(card.learningStatus),
      )
      .toList(growable: false);

  int get _availableCount =>
      _mode == StudyMode.study && _studyPresentation == StudyPresentation.draw
      ? _drawCandidates.length
      : _candidates.length;

  bool get _usesRecallFilters =>
      _mode == StudyMode.recall || _mode == StudyMode.ai;

  int get _reviewHistoryWindow =>
      ref.read(reviewProgressionSettingsProvider).value?.historyWindow ?? 5;

  bool get _isScriptStudy =>
      widget.studyCards.isNotEmpty &&
      widget.studyCards.every((card) => card.isScriptCard);

  String _cueLabel(StudyCue cue) => switch (cue) {
    StudyCue.fromLanguage => widget.fromLanguage,
    StudyCue.toLanguage => widget.toLanguage,
    StudyCue.transliteration => 'Transliteration',
  };

  void _selectCue(StudyCue cue) {
    setState(() {
      _cue = cue;
      _resetCount();
    });
    _rememberPreferences();
  }

  void _toggleLearningStatus(LearningStatus status) {
    setState(() {
      if (_learningStatuses.contains(status)) {
        if (_learningStatuses.length > 1) _learningStatuses.remove(status);
      } else {
        _learningStatuses.add(status);
      }
      _resetCount();
    });
    _rememberPreferences();
  }

  void _toggleRecallState(RecallCardState state) {
    setState(() {
      if (_recallStates.contains(state)) {
        if (_recallStates.length > 1) _recallStates.remove(state);
      } else {
        _recallStates.add(state);
      }
      _resetCount();
    });
    _rememberPreferences();
  }

  void _selectRecallTiming(RecallTiming timing) {
    setState(() {
      _recallTiming = timing;
      _resetCount();
    });
    _rememberPreferences();
  }

  void _selectRetainedMaxPercentage(double percentage) {
    setState(() {
      _retainedMaxPercentage = percentage.round();
      _resetCount();
    });
    _rememberPreferences();
  }

  void _resetCount() {
    final available = _availableCount;
    _count = min(10, max(1, available));
  }

  void _selectMode(StudyMode mode) {
    setState(() {
      _mode = mode;
      if (_usesRecallFilters &&
          _isScriptStudy &&
          !ScriptRecallPolicy.allowedCues.contains(_cue)) {
        _cue = StudyCue.fromLanguage;
      }
      _resetCount();
    });
    _rememberPreferences();
  }

  void _selectStudyPresentation(StudyPresentation presentation) {
    setState(() {
      _studyPresentation = presentation;
      _resetCount();
    });
    _rememberPreferences();
  }

  void _selectRecallPresentation(RecallPresentation presentation) {
    setState(() => _recallPresentation = presentation);
    _rememberPreferences();
  }

  void _selectOrder(StudyOrder order) {
    setState(() => _order = order);
    _rememberPreferences();
  }

  void _selectCount(double count) {
    setState(() => _count = count.round());
    _rememberPreferences();
  }

  Future<void> _start() async {
    final prompts = await _latestSelectedPrompts();
    if (!mounted || prompts == null) return;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StudyScreen(title: widget.title, prompts: prompts),
      ),
    );
    if (completed == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _startFastRecall() async {
    final prompts = await _latestSelectedPrompts();
    if (!mounted || prompts == null) return;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            LanguageFastRecallPage(title: widget.title, prompts: prompts),
      ),
    );
    if (completed == true && mounted) Navigator.of(context).pop();
  }

  Future<List<StudyPrompt>?> _latestSelectedPrompts() async {
    if (_starting || _cue == null) return null;
    setState(() => _starting = true);
    try {
      final dashboard = await ref.read(cardsDashboardProvider.future);
      final cardsById = <int, StudyCard>{
        for (final card in dashboard.cards) card.id: card,
      };
      final selected =
          <StudyPrompt>[
                for (final queued in _candidates)
                  if (cardsById[queued.cardId] case final latestCard?
                      when !latestCard.suspended &&
                          (!_usesRecallFilters ||
                              _matchesRecallFilters(latestCard)) &&
                          latestCard.scheduleFor(queued.cue).enabled)
                    StudyPrompt(card: latestCard, cue: queued.cue),
              ]
              .where(
                (prompt) =>
                    _usesRecallFilters ||
                    prompt.isNew ||
                    prompt.isDueAt(DateTime.now().toUtc()),
              )
              .toList();

      if (selected.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _usesRecallFilters
                    ? 'No cards match these filters'
                    : 'Nothing due right now',
              ),
            ),
          );
        }
        return null;
      }

      if (_usesRecallFilters || _order == StudyOrder.shuffle) {
        selected.shuffle(Random.secure());
      }
      return selected
          .take(min(_count, selected.length))
          .toList(growable: false);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh recall queue: $error')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _openStudySheet() {
    final cards = widget.studyCards
        .where((card) => card.content is LanguageCardContent && !card.suspended)
        .toList(growable: false);
    if (_order == StudyOrder.shuffle) cards.shuffle(Random.secure());
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LanguageStudyPage(title: widget.title, cards: cards),
      ),
    );
  }

  Future<void> _openDrawPractice() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final dashboard = await ref.read(cardsDashboardProvider.future);
      final eligibleIds = widget.studyCards.map((card) => card.id).toSet();
      final cards = dashboard.cards
          .where(
            (card) =>
                eligibleIds.contains(card.id) &&
                card.content is LanguageCardContent &&
                !card.suspended &&
                _learningStatuses.contains(card.learningStatus),
          )
          .toList(growable: true);
      if (_order == StudyOrder.shuffle) cards.shuffle(Random.secure());
      final selected = cards
          .take(min(_count, cards.length))
          .toList(growable: false);
      if (selected.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No letters match this selection')),
          );
        }
        return;
      }
      if (!mounted) return;
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => ScriptDrawPracticePage(
            title: widget.title,
            cards: selected,
            audioRepository: ref.read(cardAudioRepositoryProvider),
          ),
        ),
      );
      if (completed == true && mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open drawing practice: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _startAiTutor() async {
    final prompts = await _latestSelectedPrompts();
    if (!mounted || prompts == null) return;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => VoiceStudyScreen(
          title: widget.title,
          prompts: prompts,
          deckLanguages: {
            for (final deckId in widget.studyCards.map((card) => card.deckId))
              deckId: (from: widget.fromLanguage, to: widget.toLanguage),
          },
        ),
      ),
    );
    if (completed == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(cardsDashboardProvider);
    ref.watch(reviewProgressionSettingsProvider);
    final maxCount =
        _mode == StudyMode.study && _studyPresentation == StudyPresentation.draw
        ? _drawCandidates.length
        : _candidates.length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('STUDY SETUP', style: monoLabel),
                  const SizedBox(height: 8),
                  const Text(
                    'How do you want to study?',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SegmentedButton<StudyMode>(
                    segments: const [
                      ButtonSegment(
                        value: StudyMode.study,
                        label: Text('Study'),
                      ),
                      ButtonSegment(
                        value: StudyMode.recall,
                        label: Text('Recall'),
                      ),
                      ButtonSegment(
                        value: StudyMode.ai,
                        icon: Icon(Icons.auto_awesome_outlined),
                        label: Text('AI'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (value) => _selectMode(value.single),
                  ),
                  const SizedBox(height: 28),
                  if (_mode == StudyMode.study) ...[
                    if (_isScriptStudy) ...[
                      _SetupCard(
                        number: '01',
                        title: 'Study format',
                        child: SegmentedButton<StudyPresentation>(
                          segments: const [
                            ButtonSegment(
                              value: StudyPresentation.sheet,
                              label: Text('Study sheet'),
                            ),
                            ButtonSegment(
                              value: StudyPresentation.draw,
                              label: Text('Draw'),
                            ),
                          ],
                          selected: {_studyPresentation},
                          onSelectionChanged: (value) =>
                              _selectStudyPresentation(value.single),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (!_isScriptStudy ||
                        _studyPresentation == StudyPresentation.sheet) ...[
                      _SetupCard(
                        number: _isScriptStudy ? '02' : '01',
                        title: _isScriptStudy
                            ? 'All letters on one page'
                            : 'All words on one page',
                        child: Text(
                          '${widget.studyCards.length} cards with both languages, transliteration and audio',
                          style: const TextStyle(color: RecallColors.muted),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SetupCard(
                        number: _isScriptStudy ? '03' : '02',
                        title: 'Choose the order',
                        child: _OrderControl(
                          value: _order,
                          onChanged: _selectOrder,
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: widget.studyCards.isEmpty
                            ? null
                            : _openStudySheet,
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 13),
                          child: Text('Open study sheet'),
                        ),
                      ),
                    ] else ...[
                      _SetupCard(
                        number: '02',
                        title: 'Which letters?',
                        child: _learningStatusChoices(),
                      ),
                      const SizedBox(height: 14),
                      _SetupCard(
                        number: '03',
                        title: 'How many letters?',
                        child: _countControl(maxCount),
                      ),
                      const SizedBox(height: 14),
                      _SetupCard(
                        number: '04',
                        title: 'Choose the order',
                        child: _OrderControl(
                          value: _order,
                          onChanged: _selectOrder,
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: maxCount == 0 || _starting
                            ? null
                            : _openDrawPractice,
                        icon: const Icon(Icons.gesture_outlined),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 13),
                          child: Text('Start drawing'),
                        ),
                      ),
                    ],
                  ] else if (_mode == StudyMode.recall) ...[
                    if (!_isScriptStudy) ...[
                      _SetupCard(
                        number: '01',
                        title: 'Recall format',
                        child: SegmentedButton<RecallPresentation>(
                          segments: const [
                            ButtonSegment(
                              value: RecallPresentation.standard,
                              label: Text('Standard'),
                            ),
                            ButtonSegment(
                              value: RecallPresentation.fast,
                              label: Text('Fast'),
                            ),
                          ],
                          selected: {_recallPresentation},
                          onSelectionChanged: (value) =>
                              _selectRecallPresentation(value.single),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _SetupCard(
                      number: _isScriptStudy ? '01' : '02',
                      title: 'What should be in front?',
                      child: _cueChoices(),
                    ),
                    const SizedBox(height: 14),
                    _SetupCard(
                      number: _isScriptStudy ? '02' : '03',
                      title: _isScriptStudy ? 'Which letters?' : 'Which words?',
                      child: _recallFilterChoices(),
                    ),
                    const SizedBox(height: 14),
                    _SetupCard(
                      number: _isScriptStudy ? '03' : '04',
                      title: 'How many cards?',
                      child: _countControl(maxCount),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _cue == null || maxCount == 0 || _starting
                          ? null
                          : _recallPresentation == RecallPresentation.fast &&
                                !_isScriptStudy
                          ? _startFastRecall
                          : _start,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Text(
                          _recallPresentation == RecallPresentation.fast &&
                                  !_isScriptStudy
                              ? 'Start fast recall'
                              : 'Start recall',
                        ),
                      ),
                    ),
                  ] else ...[
                    _SetupCard(
                      number: '01',
                      title: 'What should be in front?',
                      child: _cueChoices(),
                    ),
                    const SizedBox(height: 14),
                    _SetupCard(
                      number: '02',
                      title: _isScriptStudy ? 'Which letters?' : 'Which words?',
                      child: _recallFilterChoices(),
                    ),
                    const SizedBox(height: 14),
                    _SetupCard(
                      number: '03',
                      title: 'How many cards?',
                      child: _countControl(maxCount),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _cue == null || maxCount == 0 || _starting
                          ? null
                          : _startAiTutor,
                      icon: const Icon(Icons.record_voice_over_outlined),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 13),
                        child: Text('Start AI tutor'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cueChoices() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final cue
          in _usesRecallFilters && _isScriptStudy
              ? ScriptRecallPolicy.allowedCues
              : StudyCue.values)
        ChoiceChip(
          label: Text(_cueLabel(cue)),
          selected: _cue == cue,
          onSelected: (_) => _selectCue(cue),
        ),
    ],
  );

  Widget _learningStatusChoices() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      FilterChip(
        label: const Text('Current'),
        selected: _learningStatuses.contains(LearningStatus.learning),
        onSelected: (_) => _toggleLearningStatus(LearningStatus.learning),
      ),
      FilterChip(
        label: const Text('Past'),
        selected: _learningStatuses.contains(LearningStatus.learnt),
        onSelected: (_) => _toggleLearningStatus(LearningStatus.learnt),
      ),
    ],
  );

  Widget _recallFilterChoices() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('TIME', style: monoLabel),
      const SizedBox(height: 8),
      _learningStatusChoices(),
      const SizedBox(height: 16),
      Text('MEMORY STATE', style: monoLabel),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final state in RecallCardState.values)
            FilterChip(
              label: Text(switch (state) {
                RecallCardState.learning => 'Learning',
                RecallCardState.relearning => 'Relearning',
                RecallCardState.retained => 'Retained',
                RecallCardState.newCard => 'New',
              }),
              selected: _recallStates.contains(state),
              onSelected: (_) => _toggleRecallState(state),
            ),
        ],
      ),
      if (_recallStates.contains(RecallCardState.retained)) ...[
        const SizedBox(height: 16),
        Row(
          children: [
            Text('RETAINED RECALL', style: monoLabel),
            const Spacer(),
            Text(
              '0–$_retainedMaxPercentage%',
              key: const ValueKey('retained-recall-range'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Slider(
          key: const ValueKey('retained-recall-slider'),
          value: _retainedMaxPercentage.toDouble(),
          min: 0,
          max: 100,
          divisions: _reviewHistoryWindow,
          label: '0–$_retainedMaxPercentage%',
          onChanged: _selectRetainedMaxPercentage,
        ),
        Text(
          'Based on the last $_reviewHistoryWindow front-to-back reviews',
          style: const TextStyle(fontSize: 12, color: RecallColors.muted),
        ),
      ],
      const SizedBox(height: 16),
      Text('REVIEW TIMING', style: monoLabel),
      const SizedBox(height: 8),
      SegmentedButton<RecallTiming>(
        segments: const [
          ButtonSegment(value: RecallTiming.allMatching, label: Text('All')),
          ButtonSegment(value: RecallTiming.dueNow, label: Text('Due')),
        ],
        selected: {_recallTiming},
        onSelectionChanged: (selection) =>
            _selectRecallTiming(selection.single),
      ),
      const SizedBox(height: 8),
      Text(
        _recallTimingSummary(),
        style: const TextStyle(fontSize: 12, color: RecallColors.muted),
      ),
    ],
  );

  String _recallTimingSummary() {
    final matching = _recallBaseCandidates.length;
    final due = _recallBaseCandidates
        .where((prompt) => _isDueForRecall(prompt.card))
        .length;
    return '$due out of $matching cards are due now';
  }

  Widget _countControl(int maxCount) => maxCount == 0
      ? const Text(
          'Choose what should be prompted first',
          style: TextStyle(color: RecallColors.faint),
        )
      : Column(
          children: [
            Row(
              children: [
                Text(
                  '$_count',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '$maxCount available',
                  style: const TextStyle(color: RecallColors.muted),
                ),
              ],
            ),
            Slider(
              value: _count.clamp(1, maxCount).toDouble(),
              min: 1,
              max: maxCount.toDouble(),
              divisions: maxCount > 1 ? maxCount - 1 : null,
              onChanged: _selectCount,
            ),
          ],
        );
}

class _OrderControl extends StatelessWidget {
  const _OrderControl({required this.value, required this.onChanged});

  final StudyOrder value;
  final ValueChanged<StudyOrder> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<StudyOrder>(
    segments: const [
      ButtonSegment(value: StudyOrder.normal, label: Text('Normal')),
      ButtonSegment(value: StudyOrder.shuffle, label: Text('Shuffle')),
    ],
    selected: {value},
    onSelectionChanged: (selection) => onChanged(selection.single),
  );
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.number,
    required this.title,
    required this.child,
  });

  final String number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number, style: monoLabel),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}
