import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/study/language_study_page.dart';
import 'package:nx_cards/features/study/language_fast_recall_page.dart';
import 'package:nx_cards/features/study/script_draw_practice_page.dart';
import 'package:nx_cards/features/study/script_recall_policy.dart';
import 'package:nx_cards/features/study/study_screen.dart';
import 'package:nx_cards/features/voice_study/voice_study_screen.dart';

enum StudyOrder { normal, shuffle }

enum StudyMode { study, recall, ai }

enum StudyPresentation { sheet, draw }

enum RecallPresentation { standard, fast }

class StudySetupScreen extends ConsumerStatefulWidget {
  const StudySetupScreen({
    super.key,
    required this.title,
    required this.prompts,
    required this.studyCards,
    required this.fromLanguage,
    required this.toLanguage,
  });

  final String title;
  final List<StudyPrompt> prompts;
  final List<StudyCard> studyCards;
  final String fromLanguage;
  final String toLanguage;

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
  StudyOrder _order = StudyOrder.normal;
  int _count = 1;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _resetCount();
  }

  List<StudyPrompt> get _candidates => _cue == null
      ? const <StudyPrompt>[]
      : widget.prompts
            .where(
              (prompt) =>
                  prompt.cue == _cue &&
                  _learningStatuses.contains(prompt.card.learningStatus),
            )
            .toList();

  List<StudyCard> get _drawCandidates => widget.studyCards
      .where(
        (card) =>
            card.content is LanguageCardContent &&
            !card.suspended &&
            _learningStatuses.contains(card.learningStatus),
      )
      .toList(growable: false);

  bool get _isScriptStudy =>
      widget.studyCards.isNotEmpty &&
      widget.studyCards.every(
        (card) => card.wordCategory?.trim().toLowerCase() == 'script',
      );

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
  }

  void _resetCount() {
    final available =
        _mode == StudyMode.study && _studyPresentation == StudyPresentation.draw
        ? _drawCandidates.length
        : _candidates.length;
    _count = min(10, max(1, available));
  }

  void _selectMode(StudyMode mode) {
    setState(() {
      _mode = mode;
      if (mode == StudyMode.recall &&
          _isScriptStudy &&
          !ScriptRecallPolicy.allowedCues.contains(_cue)) {
        _cue = StudyCue.fromLanguage;
      }
      _resetCount();
    });
  }

  void _selectStudyPresentation(StudyPresentation presentation) {
    setState(() {
      _studyPresentation = presentation;
      _resetCount();
    });
  }

  Future<void> _start() async {
    final prompts = await _latestSelectedPrompts();
    if (!mounted || prompts == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyScreen(title: widget.title, prompts: prompts),
      ),
    );
  }

  Future<void> _startFastRecall() async {
    final prompts = await _latestSelectedPrompts();
    if (!mounted || prompts == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            LanguageFastRecallPage(title: widget.title, prompts: prompts),
      ),
    );
  }

  Future<List<StudyPrompt>?> _latestSelectedPrompts() async {
    if (_starting || _cue == null) return null;
    setState(() => _starting = true);
    try {
      final dashboard = await ref.read(cardsDashboardProvider.future);
      final cardsById = <int, StudyCard>{
        for (final card in dashboard.cards) card.id: card,
      };
      final now = DateTime.now().toUtc();
      final selected =
          <StudyPrompt>[
                for (final queued in _candidates)
                  if (cardsById[queued.cardId] case final latestCard?
                      when !latestCard.suspended &&
                          _learningStatuses.contains(latestCard.learningStatus))
                    StudyPrompt(card: latestCard, cue: queued.cue),
              ]
              .where(
                (prompt) =>
                    prompt.schedule.enabled &&
                    (prompt.isNew || prompt.isDueAt(now)),
              )
              .toList();

      if (selected.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nothing due right now')),
          );
        }
        return null;
      }

      if (_order == StudyOrder.shuffle) selected.shuffle(Random.secure());
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
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ScriptDrawPracticePage(
            title: widget.title,
            cards: selected,
            audioRepository: ref.read(cardAudioRepositoryProvider),
          ),
        ),
      );
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
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
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(cardsDashboardProvider);
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
                          onChanged: (value) => setState(() => _order = value),
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
                          onChanged: (value) => setState(() => _order = value),
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
                          onSelectionChanged: (value) => setState(
                            () => _recallPresentation = value.single,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _SetupCard(
                      number: _isScriptStudy ? '01' : '02',
                      title: _isScriptStudy ? 'Which letters?' : 'Which words?',
                      child: _learningStatusChoices(),
                    ),
                    const SizedBox(height: 14),
                    _SetupCard(
                      number: _isScriptStudy ? '02' : '03',
                      title: 'What should be in front?',
                      child: _cueChoices(),
                    ),
                    const SizedBox(height: 14),
                    _SetupCard(
                      number: _isScriptStudy ? '03' : '04',
                      title: 'How many cards?',
                      child: _countControl(maxCount),
                    ),
                    const SizedBox(height: 14),
                    _SetupCard(
                      number: _isScriptStudy ? '04' : '05',
                      title: 'Choose the order',
                      child: _OrderControl(
                        value: _order,
                        onChanged: (value) => setState(() => _order = value),
                      ),
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
                      title: 'Which words?',
                      child: _learningStatusChoices(),
                    ),
                    const SizedBox(height: 14),
                    _SetupCard(
                      number: '02',
                      title: 'What should AI ask you?',
                      child: _cueChoices(),
                    ),
                    const SizedBox(height: 14),
                    _SetupCard(
                      number: '03',
                      title: 'How many cards?',
                      child: _countControl(maxCount),
                    ),
                    const SizedBox(height: 14),
                    _SetupCard(
                      number: '04',
                      title: 'Choose the order',
                      child: _OrderControl(
                        value: _order,
                        onChanged: (value) => setState(() => _order = value),
                      ),
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
          in _mode == StudyMode.recall && _isScriptStudy
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
        label: const Text('Learning'),
        selected: _learningStatuses.contains(LearningStatus.learning),
        onSelected: (_) => _toggleLearningStatus(LearningStatus.learning),
      ),
      FilterChip(
        label: const Text('Learnt'),
        selected: _learningStatuses.contains(LearningStatus.learnt),
        onSelected: (_) => _toggleLearningStatus(LearningStatus.learnt),
      ),
    ],
  );

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
              onChanged: (value) => setState(() => _count = value.round()),
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
