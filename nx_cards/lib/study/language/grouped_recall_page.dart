import 'package:nx_cards/study/language/tablet_recall_context.dart';
import 'package:nx_cards/study/session/recall_recap_page.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/card_details_page.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/scheduling/scheduling.dart';
import 'package:nx_cards/study/language/group_grade_batch.dart';
import 'package:nx_cards/study/language/drawing/native_drawing_session.dart';
import 'package:nx_cards/study/language/drawing/writing_recall_card.dart';
import 'package:nx_cards/study/language/language_audio_controls.dart';
import 'package:nx_cards/study/language/similar_sounds.dart';
import 'package:nx_cards/browser/language/similar_sounds_page.dart';

enum GroupedRecallFormat { standard, write, fast }

/// Separate session state and navigation: ordinary recall never enters here.
class GroupedRecallPage extends ConsumerStatefulWidget {
  const GroupedRecallPage({
    super.key,
    required this.groups,
    required this.format,
  });
  final List<SimilarRecallGroup> groups;
  final GroupedRecallFormat format;
  @override
  ConsumerState<GroupedRecallPage> createState() => _GroupedRecallPageState();
}

class _GroupedRecallPageState extends ConsumerState<GroupedRecallPage> {
  late final CardLibrary _library;
  late final Map<int, StudyCard> _latest;
  final Map<String, CardRating> _grades = {};
  late List<StudyPrompt> _questions;
  int _groupIndex = 0, _wordIndex = 0;
  final Set<int> _tested = {};
  bool _revealed = false, _groupComplete = false, _saving = false;
  bool _summary = false;
  bool _nativeOpening = false;
  String? _error;
  GroupGradeBatch? _batch;
  SimilarRecallGroup get _group => widget.groups[_groupIndex];
  bool get _sameSession =>
      mounted && identical(_library, ref.read(cardLibraryProvider));
  String get _answerKey => '$_groupIndex:$_wordIndex';
  StudyPrompt get _prompt =>
      _questions[_wordIndex].withCard(_latest[_questions[_wordIndex].cardId]!);

  @override
  void initState() {
    super.initState();
    _library = ref.read(cardLibraryProvider);
    _latest = {
      for (final g in widget.groups)
        for (final c in g.comparisonCards) c.id: c,
    };
    _questions = widget.groups.isEmpty ? [] : List.of(_group.prompts);
    _summary = widget.groups.isEmpty;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _startNativeIfAvailable(),
    );
  }

  void _advanceWord() {
    _tested.add(_wordIndex);
    setState(() {
      if (_wordIndex + 1 == _questions.length) {
        _groupComplete = true;
      } else {
        _wordIndex++;
        _revealed = false;
      }
    });
    if (_groupComplete && !_nativeOpening) _nextGroup();
  }

  void _end() {
    if (_saving || _batch != null && !_batch!.complete) return;
    setState(() => _summary = true);
  }

  Future<bool> _grade(CardRating rating) async {
    if (_saving || !_sameSession) return false;
    if (_grades.containsKey(_answerKey)) return true;
    setState(() {
      _saving = true;
      _error = null;
    });
    _batch ??= GroupGradeBatch(
      prompts: [_prompt],
      latest: _latest,
      scheduler: ref.read(cardSchedulerProvider),
      now: DateTime.now().toUtc(),
      rating: rating,
    );
    try {
      await _batch!.save((card) async {
        if (!_sameSession) {
          throw StateError('Account changed. Close this session.');
        }
        await _library.saveSchedule(card);
      }, _latest);
      if (!_sameSession) return false;
      ref.read(cardsInvalidationProvider)();
      _grades[_answerKey] = _batch!.rating;
      _batch = null;
      _advanceWord();
      return true;
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save this answer. Retry saving.');
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _nextGroup({bool openNative = true}) {
    if (_groupIndex + 1 == widget.groups.length) {
      setState(() => _summary = true);
      return;
    }
    setState(() {
      _groupIndex++;
      _wordIndex = 0;
      _revealed = false;
      _groupComplete = false;
      _tested.clear();
      _batch = null;
      _error = null;
      _questions = List.of(_group.prompts);
    });
    if (openNative) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startNativeIfAvailable(),
      );
    }
  }

  Future<void> _startNativeIfAvailable() async {
    if (_summary ||
        widget.format == GroupedRecallFormat.fast ||
        !_sameSession) {
      return;
    }
    setState(() => _nativeOpening = true);
    var continueNative = false;
    try {
      if (!await NativeDrawingSession.isAvailable() || !_sameSession) return;
      final audio = ref.read(cardAudioRepositoryProvider);
      final handled = await NativeDrawingSession.open(
        title: 'Similar words · Group ${_groupIndex + 1}',
        cards: [
          for (final p in _questions)
            NativeDrawingSession.recallCard(
              p.withCard(_latest[p.cardId]!),
              similar: similarGroupsForCard(_latest[p.cardId]!, _latest.values),
            ),
        ],
        recall: true,
        onAction: (call) async {
          if (!_sameSession) throw PlatformException(code: 'session_changed');
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          final index = args['index'];
          if (index is! int || index < 0 || index >= _questions.length) {
            throw PlatformException(code: 'invalid_card');
          }
          if (call.method == 'rate') {
            if (_tested.contains(index)) return null;
            if (index != _wordIndex) {
              throw PlatformException(code: 'invalid_order');
            }
            final saved = await _grade(
              args['correct'] == true ? CardRating.good : CardRating.again,
            );
            if (!saved) {
              throw PlatformException(code: 'save_failed', message: _error);
            }
            return null;
          }
          final content = _questions[index].card.content as LanguageCardContent;
          final similarCards = similarGroupsForCard(
            _questions[index].card,
            _latest.values,
          ).expand((g) => g.cards).toList();
          if (call.method == 'audio') {
            final exampleIndex = args['exampleIndex'];
            final similarCardId = args['similarCardId'];
            if (similarCardId != null && exampleIndex != null) {
              throw PlatformException(code: 'invalid_audio_target');
            }
            var url = content.audioUrl;
            if (similarCardId != null) {
              final target = similarCards
                  .where((c) => c.id == similarCardId)
                  .firstOrNull;
              if (target?.content case final LanguageCardContent word) {
                url = word.audioUrl;
              } else {
                throw PlatformException(code: 'invalid_similar_card');
              }
            }
            if (exampleIndex != null) {
              if (exampleIndex is! int ||
                  exampleIndex < 0 ||
                  exampleIndex >= content.examples.length) {
                throw PlatformException(code: 'invalid_example');
              }
              url = content.examples[exampleIndex].audioUrl;
            }
            if (audio == null || url == null || url.isEmpty) {
              throw PlatformException(code: 'audio_unavailable');
            }
            return audio.fetch(url);
          }
          if (call.method == 'exampleCard') {
            final id = args['cardId'];
            if (!content.examples.any((e) => e.cardId == id) &&
                !similarCards.any((c) => c.id == id)) {
              throw PlatformException(code: 'invalid_example');
            }
            final data = await ref.read(cardsDashboardProvider.future);
            final target = data.cards.where((c) => c.id == id).firstOrNull;
            if (!mounted || !_sameSession || target == null) {
              throw PlatformException(code: 'example_unavailable');
            }
            final details = Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => CardDetailsPage(card: target, allowEdit: false),
              ),
            );
            try {
              await NativeDrawingSession.channel.invokeMethod<void>(
                'showFlutter',
              );
              await details;
            } finally {
              await NativeDrawingSession.channel.invokeMethod<void>(
                'resumeDrawing',
              );
            }
            return null;
          }
          throw PlatformException(code: 'unsupported_action');
        },
      );
      if (!handled || !_sameSession) return;
      if (_batch != null) {
        setState(() => _revealed = true);
        return;
      }
      if (_groupComplete) {
        _nextGroup(openNative: false);
        continueNative = !_summary;
      } else {
        setState(() => _summary = true);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not open the writing screen. You can continue below.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _nativeOpening = false);
        if (continueNative) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _startNativeIfAvailable(),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild promptly if the selected account/domain changes.
    final library = ref.watch(cardLibraryProvider);
    if (!identical(library, _library)) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Account changed. Close this session.')),
      );
    }
    if (_summary) return _summaryPage();
    final blocked = _saving || _batch != null && !_batch!.complete;
    return PopScope(
      canPop: !blocked,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Similar words'),
          actions: [
            TextButton(
              onPressed: _nativeOpening || blocked ? null : _end,
              child: const Text('End'),
            ),
          ],
        ),
        body: _nativeOpening
            ? const Center(child: CircularProgressIndicator())
            : _questionBody(),
        bottomNavigationBar: _nativeOpening
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: _questionActions(),
                ),
              ),
      ),
    );
  }

  Widget _questionBody() {
    final prompt = _prompt;
    final content = prompt.card.content as LanguageCardContent;
    final audio = ref.watch(cardAudioRepositoryProvider);
    final fast = widget.format == GroupedRecallFormat.fast;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Group ${_groupIndex + 1} of ${widget.groups.length} · Word ${_wordIndex + 1} of ${_questions.length}',
                ),
                const SizedBox(height: 8),
                Text(switch (prompt.cue) {
                  StudyCue.fromAudio => 'Sound',
                  StudyCue.toLanguage => prompt.card.language ?? 'Text',
                  _ => 'English',
                }),
                const SizedBox(height: 16),
                if (_error != null) Text(_error!),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(fast ? 18 : 28),
                    child: widget.format != GroupedRecallFormat.fast
                        ? SizedBox(
                            height: max(420, constraints.maxHeight - 160),
                            child: WritingRecallCard(
                              key: ValueKey(
                                'group-write-$_groupIndex-$_wordIndex',
                              ),
                              prompt: prompt,
                              revealed: _revealed,
                              audioRepository: audio,
                            ),
                          )
                        : InkWell(
                            onTap: () => setState(() => _revealed = true),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: fast ? 120 : 280,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!_revealed)
                                    Text(
                                      prompt.prompt,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: fast ? 24 : 36,
                                      ),
                                    ),
                                  if (_revealed) ...[
                                    Text(
                                      content.originalScript,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: fast ? 28 : 40,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      content.english,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      content.transliteration,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  ],
                                  if ((prompt.isListening || _revealed) &&
                                      content.audioUrl?.isNotEmpty == true &&
                                      audio != null) ...[
                                    const SizedBox(height: 14),
                                    PronunciationButton(
                                      key: ValueKey(
                                        'group-audio-$_groupIndex-$_wordIndex',
                                      ),
                                      audioUrl: content.audioUrl!,
                                      repository: audio,
                                      autoPlay: true,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
                if (_revealed)
                  TabletRecallContext(
                    key: ValueKey('context-$_groupIndex-$_wordIndex'),
                    card: prompt.card,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _questionActions() {
    if (_saving) return const Center(child: CircularProgressIndicator());
    if (_batch != null) {
      return FilledButton(
        onPressed: () => _grade(_batch!.rating),
        child: const Text('Retry saving'),
      );
    }
    if (!_revealed) {
      return FilledButton(
        key: const ValueKey('group-question-next'),
        onPressed: () => setState(() => _revealed = true),
        child: const Text('Show answer'),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('group-not-recalled'),
            onPressed: () => _grade(CardRating.again),
            child: const Text('Not recalled'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            key: const ValueKey('group-recalled'),
            onPressed: () => _grade(CardRating.good),
            child: const Text('Recalled'),
          ),
        ),
      ],
    );
  }

  Widget _summaryPage() {
    final prompts = widget.groups.expand((g) => g.prompts).toList();
    final entries = <RecallRecapEntry>[
      for (var g = 0; g < widget.groups.length; g++)
        for (var i = 0; i < widget.groups[g].prompts.length; i++)
          RecallRecapEntry(
            card: _latest[widget.groups[g].prompts[i].cardId]!,
            rating: _grades['$g:$i'],
          ),
    ];
    return RecallRecapPage(
      reviewedCount: _grades.length,
      totalCount: prompts.length,
      missCount: _grades.values.where((r) => r == CardRating.again).length,
      entries: entries,
      onRepeatIncorrect: () {
        final retry = <SimilarRecallGroup>[];
        for (var g = 0; g < widget.groups.length; g++) {
          final group = widget.groups[g];
          final missed = [
            for (var i = 0; i < group.prompts.length; i++)
              if (_grades['$g:$i'] == null ||
                  _grades['$g:$i'] == CardRating.again)
                group.prompts[i].withCard(_latest[group.prompts[i].cardId]!),
          ];
          if (missed.isNotEmpty) {
            retry.add(
              SimilarRecallGroup(
                prompts: missed..shuffle(),
                comparisonCards: [
                  for (final c in group.comparisonCards) _latest[c.id]!,
                ],
                label: group.label,
              ),
            );
          }
        }
        if (retry.isNotEmpty) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => GroupedRecallPage(
                groups: retry..shuffle(),
                format: widget.format,
              ),
            ),
          );
        }
      },
      wordRecapTitle: 'GROUPS',
      wordRecap: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var g = 0; g < widget.groups.length; g++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${similarGroupTitle(widget.groups[g].label)} · ${switch (widget.groups[g].prompts.first.cue) {
                        StudyCue.fromAudio => 'Sound',
                        StudyCue.toLanguage => widget.groups[g].prompts.first.card.language ?? 'Text',
                        _ => 'English',
                      }}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SimilarSoundGrid(
                      cards: [
                        for (final c in widget.groups[g].comparisonCards)
                          _latest[c.id]!,
                      ],
                      ratings: {
                        for (
                          var i = 0;
                          i < widget.groups[g].prompts.length;
                          i++
                        )
                          widget.groups[g].prompts[i].cardId: _grades['$g:$i'],
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
