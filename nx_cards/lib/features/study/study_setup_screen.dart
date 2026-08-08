import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/study/language_study_page.dart';
import 'package:nx_cards/features/study/study_screen.dart';

enum StudyOrder { normal, shuffle }

enum StudyMode { study, recall }

class StudySetupScreen extends StatefulWidget {
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
  State<StudySetupScreen> createState() => _StudySetupScreenState();
}

class _StudySetupScreenState extends State<StudySetupScreen> {
  StudyMode _mode = StudyMode.study;
  StudyCue? _cue;
  StudyOrder _order = StudyOrder.normal;
  int _count = 1;

  List<StudyPrompt> get _candidates => _cue == null
      ? const <StudyPrompt>[]
      : widget.prompts.where((prompt) => prompt.cue == _cue).toList();

  String _cueLabel(StudyCue cue) => switch (cue) {
    StudyCue.fromLanguage => widget.fromLanguage,
    StudyCue.toLanguage => widget.toLanguage,
    StudyCue.transliteration => 'Transliteration',
  };

  void _selectCue(StudyCue cue) {
    final available = widget.prompts
        .where((prompt) => prompt.cue == cue)
        .length;
    setState(() {
      _cue = cue;
      _count = min(10, max(1, available));
    });
  }

  void _start() {
    if (_cue == null || _candidates.isEmpty) return;
    final selected = [..._candidates];
    if (_order == StudyOrder.shuffle) selected.shuffle(Random.secure());
    final prompts = selected.take(_count).toList(growable: false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyScreen(title: widget.title, prompts: prompts),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final maxCount = _candidates.length;
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
                    ],
                    selected: {_mode},
                    onSelectionChanged: (value) =>
                        setState(() => _mode = value.single),
                  ),
                  const SizedBox(height: 28),
                  if (_mode == StudyMode.study) ...[
                    _SetupCard(
                      number: '01',
                      title: 'All words on one page',
                      child: Text(
                        '${widget.studyCards.length} cards with both languages, transliteration and audio',
                        style: const TextStyle(color: RecallColors.muted),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SetupCard(
                      number: '02',
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
                      number: '01',
                      title: 'What should be in front?',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final cue in StudyCue.values)
                            ChoiceChip(
                              label: Text(_cueLabel(cue)),
                              selected: _cue == cue,
                              onSelected: (_) => _selectCue(cue),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _SetupCard(
                      number: '02',
                      title: 'What should be in back?',
                      child: _EverythingAnswer(),
                    ),
                    const SizedBox(height: 14),
                    _SetupCard(
                      number: '03',
                      title: 'How many cards?',
                      child: maxCount == 0
                          ? const Text(
                              'Choose the front first',
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
                                      style: const TextStyle(
                                        color: RecallColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                                Slider(
                                  value: _count.clamp(1, maxCount).toDouble(),
                                  min: 1,
                                  max: maxCount.toDouble(),
                                  divisions: maxCount > 1 ? maxCount - 1 : null,
                                  onChanged: (value) =>
                                      setState(() => _count = value.round()),
                                ),
                              ],
                            ),
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
                      onPressed: _cue == null || maxCount == 0 ? null : _start,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 13),
                        child: Text('Start recall'),
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

class _EverythingAnswer extends StatelessWidget {
  const _EverythingAnswer();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Icon(Icons.check_circle_outline, size: 19, color: RecallColors.ink),
      SizedBox(width: 9),
      Expanded(
        child: Text(
          'Everything — both languages, transliteration, audio and examples',
          style: TextStyle(color: RecallColors.muted),
        ),
      ),
    ],
  );
}
