import 'package:nx_cards/study/recall_direction_choices.dart';
import 'package:nx_cards/study/current_date_groups.dart';
import 'package:nx_cards/study/language/similar_sounds.dart';
import 'package:nx_cards/scheduling/retention.dart';
import 'package:nx_cards/scheduling/language_direction.dart';
import 'package:nx_cards/scheduling/study_scope.dart';
import 'package:nx_cards/study/lazy_study_queue.dart';
import 'package:nx_cards/study/recall_priority.dart';
import 'package:nx_cards/study/hydrate_study_queue.dart';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:nx_cards/account/account_session.dart';
import 'package:nx_cards/scheduling/scheduling.dart';
import 'package:nx_cards/study/session/recall_recap_page.dart';
import 'package:nx_cards/study/language/drawing/native_drawing_session.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/card_details_page.dart';
import 'package:nx_cards/study/language/language_study_page.dart';
import 'package:nx_cards/study/language/language_fast_recall_page.dart';
import 'package:nx_cards/study/language/drawing/script_draw_practice_page.dart';
import 'package:nx_cards/study/language/drawing/recall_interaction.dart';
import 'package:nx_cards/study/session/study_session_page.dart';
import 'package:nx_cards/tutor/voice_tutor_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StudyOrder { normal, shuffle }

enum StudyMode { study, recall, ai }

enum StudySetupFlow { practice, recall }

enum StudySourceKind { language, book }

enum StudyPresentation { sheet, draw }

enum RecallPresentation { standard, fast }

enum RecallCardState { learning, relearning, retained, newCard }

enum RecallTiming { allMatching, dueNow, byDate }

class StudySetupPage extends ConsumerStatefulWidget {
  const StudySetupPage({
    this.studyScope,
    this.flow = StudySetupFlow.recall,
    super.key,
    required this.title,
    required this.prompts,
    required this.studyCards,
    required this.fromLanguage,
    required this.toLanguage,
    this.preferenceKey,
    this.sourceKind = StudySourceKind.language,
  });

  final StudySetupFlow flow;
  final StudyScope? studyScope;
  final String title;
  final List<StudyPrompt> prompts;
  final List<StudyCard> studyCards;
  final String fromLanguage;
  final String toLanguage;
  final String? preferenceKey;
  final StudySourceKind sourceKind;

  @override
  ConsumerState<StudySetupPage> createState() => _StudySetupPageState();
}

class _StudySetupPageState extends ConsumerState<StudySetupPage> {
  late StudyMode _mode;
  StudyPresentation _studyPresentation = StudyPresentation.sheet;
  RecallPresentation _recallPresentation = RecallPresentation.standard;
  late Set<RecallComponent> _directions;
  Set<StudyCue> _recallCues = StudyCue.languageDirections.toSet();
  bool get _explicitDirections => _mode == StudyMode.recall && _supportsDrawing;
  bool _matchesSelectedCue(StudyCue cue) =>
      !_explicitDirections || _recallCues.contains(cue);
  bool _writing = true;
  bool _sound = true;
  bool _silent = false;
  bool get _sessionSound =>
      _mode == StudyMode.ai || (_mode == StudyMode.recall ? !_silent : _sound);
  bool _screenWide = false;
  bool get _wideRecall => _mode == StudyMode.recall && _screenWide;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenWide = MediaQuery.sizeOf(context).width >= 600;
    _clampCount();
  }

  bool get _allowsWriting => (_wideRecall || _writing) && _supportsDrawing;
  Set<RecallComponent>? _regularDirections;
  RecallComponent? get _cue => _directions.firstOrNull;
  final bool _combinedPrompt = false;

  List<StudyCard>? _dashboardCards, _inputCards, _scopedCards;
  List<StudyCard> get _studyCards {
    final latest = ref.read(cardsDashboardProvider).value?.cards;
    if (latest == null) return widget.studyCards;
    if (!identical(latest, _dashboardCards) ||
        !identical(widget.studyCards, _inputCards)) {
      _dashboardCards = latest;
      _inputCards = widget.studyCards;
      final ids = widget.studyCards.map((card) => card.id).toSet();
      _scopedCards = latest.where((card) => ids.contains(card.id)).toList();
    }
    return _scopedCards!;
  }

  RecallTiming _timing = RecallTiming.allMatching;
  bool get _dueOnly =>
      _mode == StudyMode.recall && _timing == RecallTiming.dueNow;
  bool get _byDate =>
      _mode == StudyMode.recall && _timing == RecallTiming.byDate;
  Set<String> _selectedDates = {};
  List<StudyCard>? _dateGroupCards;
  Map<String, int> _cachedDateGroups = {};
  Map<String, int> get _dateGroups {
    final cards = _studyCards;
    if (!identical(cards, _dateGroupCards)) {
      _dateGroupCards = cards;
      _cachedDateGroups = recentCurrentDateGroups(cards);
    }
    return _cachedDateGroups;
  }

  List<String> get _dateRange {
    final dates = _dateGroups.keys.toList()..sort();
    final selected = dates.where(_selectedDates.contains).toList();
    if (dates.isEmpty) return const [];
    if (selected.isEmpty) return [dates.last];
    return dates
        .where(
          (date) =>
              date.compareTo(selected.first) >= 0 &&
              date.compareTo(selected.last) <= 0,
        )
        .toList();
  }

  bool _matchesDate(StudyCard card) =>
      !_byDate || _dateRange.contains(card.addedToCurrentAt);
  int _dueMinPercentage = 0;
  int _retainedMinPercentage = 0;
  bool _weakOnly = false;
  bool _newOnly = false;
  int _retainedMaxPercentage = 100;
  StudyOrder _order = StudyOrder.normal;
  int _count = 10;
  bool _starting = false;
  int get _displayCount => _count;
  int _preferenceRevision = 0;

  String get _storedPreferenceKey =>
      'study_setup.v4.${widget.flow.name}.${widget.preferenceKey ?? widget.title}';

  @override
  void initState() {
    super.initState();
    _directions = _isBookStudy
        ? {RecallComponent.meaning}
        : {
            ...ref.read(
              selectedDirectionsProvider(
                widget.studyScope?.language ?? widget.toLanguage,
              ),
            ),
          };
    _mode = widget.flow == StudySetupFlow.practice
        ? StudyMode.study
        : StudyMode.recall;
    _clampCount();
    unawaited(_restorePreferences());
  }

  Future<void> _restorePreferences() async {
    final revision = _preferenceRevision;
    final preferences = await SharedPreferences.getInstance();
    final raw =
        preferences.getString(_storedPreferenceKey) ??
        preferences.getString(
          'study_setup.v2.${widget.preferenceKey ?? widget.title}',
        );
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
        saved['recallPresentation'] == 'write'
            ? 'standard'
            : saved['recallPresentation'],
      );
      final order = _enumByName(StudyOrder.values, saved['order']);
      final retainedMaxPercentage = saved['retainedMaxPercentage'];
      setState(() {
        if (widget.flow == StudySetupFlow.recall &&
            (mode == StudyMode.recall || mode == StudyMode.ai)) {
          _mode = mode!;
        }
        if (studyPresentation != null) {
          _studyPresentation = studyPresentation;
        }
        if (recallPresentation != null) {
          _recallPresentation = recallPresentation;
        }

        if (order != null) _order = order;
        if (retainedMaxPercentage is int) {
          _retainedMaxPercentage = retainedMaxPercentage.clamp(0, 100);
        }
        _retainedMinPercentage = (saved['retainedMinPercentage'] as int? ?? 0)
            .clamp(0, _retainedMaxPercentage);
        _dueMinPercentage = (saved['dueMinPercentage'] as int? ?? 0).clamp(
          0,
          100,
        );
        _weakOnly = saved['weakOnly'] == true;
        _newOnly = saved['newOnly'] == true;
        if (_weakOnly) {
          _retainedMinPercentage = 0;
          _retainedMaxPercentage = 60;
        }
        _writing = saved['writing'] != false;
        _sound = saved['sound'] != false;
        _silent = saved['silent'] == true;
        if (saved['recallCues'] case final List values) {
          _recallCues = StudyCue.languageDirections
              .where((cue) => values.contains(cue.storageKey))
              .toSet();
        }
        _selectedDates = (saved['selectedDates'] as List? ?? [])
            .whereType<String>()
            .toSet();
        _timing =
            _enumByName(RecallTiming.values, saved['timing']) ??
            RecallTiming.allMatching;
        final savedCount = saved['count'];
        _count = savedCount is int ? max(1, savedCount) : 10;
        _normalizeAiDirections();
        _clampCount();
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
        'combinedPrompt': _combinedPrompt,
        'retainedMaxPercentage': _retainedMaxPercentage,
        'retainedMinPercentage': _retainedMinPercentage,
        'dueMinPercentage': _dueMinPercentage,
        'weakOnly': _weakOnly,
        'newOnly': _newOnly,
        'writing': _writing,
        'sound': _sound,
        'silent': _silent,
        'recallCues': _recallCues.map((cue) => cue.storageKey).toList(),
        'timing': _timing.name,
        'selectedDates': _selectedDates.toList()..sort(),
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
    return _recallBaseCandidates;
  }

  List<StudyPrompt> get _recallBaseCandidates {
    final dueOnly = _dueOnly;
    final now = DateTime.now();
    return combineRecallPrompts(
          retentionPrompts(
            _studyCards.where(_matchesDate),
            _explicitDirections ? RecallComponent.values.toSet() : _directions,

            writing: _mode == StudyMode.ai ? false : _allowsWriting,
            sound: true,
            minimum: _byDate
                ? 0
                : (dueOnly ? _dueMinPercentage : _retainedMinPercentage) / 100,
            maximum: dueOnly || _byDate ? 1 : _retainedMaxPercentage / 100,
            weakOnly: !dueOnly && !_byDate && _weakOnly,
            newOnly: !dueOnly && !_byDate && _newOnly,
          ).where(
            (prompt) =>
                _matchesSelectedCue(prompt.cue) &&
                (_sessionSound || !prompt.isListening) &&
                (!dueOnly || prompt.schedule.isDueAt(now)) &&
                (_mode != StudyMode.ai || !prompt.cue.involvesScript),
          ),
        )
        .map(
          (prompt) => prompt.forRecall(
            writing: _mode != StudyMode.ai && _allowsWriting,
          ),
        )
        .toList();
  }

  bool _matchesRecallBaseFilters(StudyCard card, [StudyCue? cue]) {
    if (_mode == StudyMode.study) return true;
    return card.active &&
        _matchesDate(card) &&
        card.learningStatus == LearningStatus.recall &&
        (cue == null ? selectedCues(card, _directions) : [cue]).any(
          (direction) => matchesRecallRange(
            card,
            direction,
            minimum: _byDate
                ? 0
                : (_dueOnly ? _dueMinPercentage : _retainedMinPercentage) / 100,
            maximum: _dueOnly || _byDate ? 1 : _retainedMaxPercentage / 100,
            weakOnly: !_dueOnly && !_byDate && _weakOnly,
            newOnly: !_dueOnly && !_byDate && _newOnly,
          ),
        );
  }

  List<StudyPrompt> get _practiceCandidates => [
    for (final card in _studyCards)
      if (!card.suspended && _matchesRecallBaseFilters(card))
        for (final cue in selectedCues(card, _directions))
          if (card.supportsCue(cue)) StudyPrompt(card: card, cue: cue),
  ];
  int get _availableCount =>
      _usesRecallFilters ? _candidates.length : _availableCardCount;

  int get _availableCardCount =>
      (_mode == StudyMode.study ? _practiceCandidates : _candidates)
          .map((prompt) => prompt.card.id)
          .toSet()
          .length;

  bool get _usesRecallFilters =>
      _mode == StudyMode.recall || _mode == StudyMode.ai;

  bool get _supportsDrawing =>
      !_isBookStudy &&
      _studyCards.isNotEmpty &&
      _studyCards.every((card) => card.isLanguageCard);

  String get _selectionTitle =>
      _mode == StudyMode.study ? 'Which cards?' : 'Recall directions';

  bool get _isBookStudy => widget.sourceKind == StudySourceKind.book;

  void _selectRetainedRange(RangeValues range) {
    setState(() {
      _retainedMaxPercentage = range.end.round();
      _retainedMinPercentage = range.start.round();
      _weakOnly = false;
      _newOnly = false;
      _clampCount();
    });
    _rememberPreferences();
  }

  void _clampCount() {
    final available = _availableCount;
    if (available > 0) {
      _count = _count.clamp(1, available);
    }
  }

  void _normalizeAiDirections() {
    if (_mode != StudyMode.ai || _isBookStudy) return;
    _directions = _directions
        .where((cue) => cue != RecallComponent.script)
        .toSet();
    if (_directions.isEmpty) {
      _directions = {RecallComponent.meaning, RecallComponent.sound};
    }
  }

  void _selectMode(StudyMode mode) {
    setState(() {
      if (mode == StudyMode.ai && _mode != StudyMode.ai) {
        _regularDirections = {..._directions};
      } else if (_mode == StudyMode.ai &&
          mode == StudyMode.recall &&
          _regularDirections != null) {
        _directions = _regularDirections!;
      }
      _mode = mode;
      _normalizeAiDirections();
      _clampCount();
    });
    _rememberPreferences();
  }

  void _selectStudyPresentation(StudyPresentation presentation) {
    setState(() {
      _studyPresentation = presentation;
      _clampCount();
    });
    _rememberPreferences();
  }

  void _selectRecallPresentation(RecallPresentation presentation) {
    setState(() {
      _recallPresentation = presentation;
      _clampCount();
    });
    _rememberPreferences();
  }

  void _selectCount(double count) {
    setState(() {
      _count = count.round();
    });
    _rememberPreferences();
  }

  Future<void> _refreshSetup() async {
    if (!mounted) return;
    try {
      await ref.read(cardsDashboardProvider.future);
      if (!mounted) return;
      setState(_clampCount);
      _rememberPreferences();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh study setup: $error')),
        );
      }
    }
  }

  Stopwatch? _startupClock;
  int _startupLast = 0;
  String _startupId = '';
  void _beginStartup(String mode) {
    _startupId = '${DateTime.now().millisecondsSinceEpoch}-$mode';
    _startupClock = Stopwatch()..start();
    _startupLast = 0;
    _startupStep('tap');
  }

  void _startupStep(String stage) {
    final elapsed = _startupClock?.elapsedMilliseconds ?? 0;
    final message =
        'NxCardsStartup id=$_startupId stage=$stage epoch_ms=${DateTime.now().millisecondsSinceEpoch} delta_ms=${elapsed - _startupLast} total_ms=$elapsed';
    developer.log(message, name: 'NxCardsStartup');
    // Keep diagnostic timings visible in release-device logcat too.
    debugPrint(message);
    _startupLast = elapsed;
  }

  Future<void> _start() async {
    _beginStartup('recall');
    final prompts = await _latestSelectedPrompts(
      deferBodies:
          _allowsWriting &&
          _recallPresentation == RecallPresentation.standard &&
          await NativeDrawingSession.isAvailable(),
    );
    if (!mounted || prompts == null) return;
    if (_allowsWriting &&
        _recallPresentation == RecallPresentation.standard &&
        prompts.every((p) => p.card.content is LanguageCardContent)) {
      try {
        if (await _openNativeDrawing(prompts: prompts)) {
          await _refreshSetup();
          return;
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not start recall: $error')),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() => _starting = true);
    try {
      // Native sessions load bodies lazily. Any Flutter fallback needs the full
      // histories before previewing grades, otherwise saving would lose them.
      final cards = await hydrateStudyQueue(
        prompts.map((prompt) => prompt.card).toList(),
        (card) => hydrateStudyCard(ref, card),
      );
      if (!mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => _withSessionSound(
            StudySessionPage(
              studyScope: widget.studyScope,
              title: widget.title,
              prompts: [
                for (var i = 0; i < prompts.length; i++)
                  prompts[i].withCard(cards[i]),
              ],
              interaction:
                  _allowsWriting &&
                      _recallPresentation == RecallPresentation.standard
                  ? RecallInteraction.writing
                  : RecallInteraction.standard,
            ),
          ),
        ),
      );
      await _refreshSetup();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recall: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<bool> _openNativeDrawing({
    List<StudyCard>? cards,
    List<StudyPrompt>? prompts,
    List<StudyPrompt>? practicePrompts,
  }) async {
    if (!await NativeDrawingSession.isAvailable() || !mounted) return false;
    _startupStep('native_available');
    final recall = prompts != null;
    final queue = cards ?? prompts!.map((p) => p.card).toList();
    final sessionKey = ref.read(activeCardsSessionProvider).value?.account.key;
    final library = ref.read(cardLibraryProvider);
    final scheduler = ref.read(cardSchedulerProvider);
    final audio = ref.read(cardAudioRepositoryProvider);
    final latest = {for (final card in queue) card.id: card};
    final ratings = <int, CardRating>{};
    final pendingOutcomes = <int, StudyCard>{};
    final linkedLibrary = {
      for (final card in (await ref.read(cardsDashboardProvider.future)).cards)
        card.id: card,
    };
    _startupStep('library_snapshot count=${linkedLibrary.length}');
    final characters = List<List<LanguageCardContent>>.generate(
      queue.length,
      (_) => [],
    );
    final characterCardIds = <LanguageCardContent, int>{};
    final derived = List<List<DerivedLanguageExample>>.generate(
      queue.length,
      (_) => [],
    );
    var closed = false;
    void checkSession() {
      if (closed ||
          !mounted ||
          sessionKey !=
              ref.read(activeCardsSessionProvider).value?.account.key) {
        throw PlatformException(code: 'session_changed');
      }
    }

    final preparations = LazyStudyQueue<Map<String, Object?>>(queue.length, (
      index,
    ) async {
      checkSession();
      final clock = Stopwatch()..start();
      final full = await hydrateStudyCard(ref, latest[queue[index].id]!);
      checkSession();
      queue[index] = full;
      // Do not replace a schedule updated by a previous recall cue.
      if (latest[full.id]!.isSummary) latest[full.id] = full;
      await NativeDrawingSession.hydrateExampleParents(
        [full],
        linkedLibrary,
        (card) => hydrateStudyCard(ref, card),
      );
      checkSession();
      final parts = NativeDrawingSession.characterCards(full, linkedLibrary);
      characters[index] = [
        for (final part in parts) part.content as LanguageCardContent,
      ];
      characterCardIds.addAll({
        for (final part in parts) part.content as LanguageCardContent: part.id,
      });
      derived[index] = NativeDrawingSession.derivedExamples(
        full,
        linkedLibrary,
      );
      debugPrint(
        'NxCardsStartup stage=card_prepared index=$index elapsed_ms=${clock.elapsedMilliseconds}',
      );
      return recall
          ? NativeDrawingSession.recallCard(
              prompts[index].withCard(full),
              writing: _allowsWriting,
              sound: _sessionSound,
              similar: similarGroupsForCard(full, linkedLibrary.values),
              characters: characters[index],
              characterCardIds: characterCardIds,
              derived: derived[index],
            )
          : NativeDrawingSession.practiceCard(
              full,
              cue: practicePrompts?[index].cue,
              similar: similarGroupsForCard(full, linkedLibrary.values),
              characters: characters[index],
              characterCardIds: characterCardIds,
              derived: derived[index],
            );
    });

    final first = await preparations.prepare(0);
    _startupStep('first_card_ready');
    final bool handled;
    try {
      handled = await NativeDrawingSession.open(
        title: widget.title,
        cards: [
          first,
          for (var i = 1; i < queue.length; i++) {'pending': true},
        ],
        recall: recall,
        onAction: (call) async {
          if (!mounted ||
              sessionKey !=
                  ref.read(activeCardsSessionProvider).value?.account.key) {
            throw PlatformException(
              code: 'session_changed',
              message: 'Account changed. Close this study session.',
            );
          }
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          final index = args['index'] as int;
          if (index < 0 || index >= queue.length) {
            throw PlatformException(code: 'invalid_card');
          }
          if (call.method == 'prepare') return preparations.prepare(index);
          if (call.method == 'exampleCard') {
            final targetId = args['cardId'];
            final parent = queue[index].content as LanguageCardContent;
            final permitted = {
              queue[index].id,
              ...parent.examples.map((e) => e.cardId),
              ...characters[index].map((part) => characterCardIds[part]),
              ...derived[index].map((e) => e.example.cardId),
              ...similarGroupsForCard(
                queue[index],
                linkedLibrary.values,
              ).expand((g) => g.cards).map((c) => c.id),
            };
            final target = targetId == queue[index].id
                ? latest[targetId]
                : targetId is int
                ? linkedLibrary[targetId]
                : null;
            if (target == null ||
                target.content is! LanguageCardContent ||
                !permitted.contains(targetId)) {
              throw PlatformException(
                code: 'example_unavailable',
                message: 'This example card is not available.',
              );
            }
            final details = Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => CardDetailsPage(card: target)),
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
          if (call.method == 'audio') {
            final content = queue[index].content as LanguageCardContent;
            final exampleIndex = args['exampleIndex'];
            final characterIndex = args['characterIndex'];
            final derivedIndex = args['derivedIndex'];
            final similarCardId = args['similarCardId'];
            if ([
                  exampleIndex,
                  characterIndex,
                  derivedIndex,
                  similarCardId,
                ].where((v) => v != null).length >
                1) {
              throw PlatformException(code: 'invalid_audio_target');
            }
            var audioUrl = content.audioUrl;
            if (similarCardId != null) {
              final target =
                  similarGroupsForCard(queue[index], linkedLibrary.values)
                      .expand((g) => g.cards)
                      .where((c) => c.id == similarCardId)
                      .firstOrNull;
              if (target?.content case final LanguageCardContent word) {
                audioUrl = word.audioUrl;
              } else {
                throw PlatformException(code: 'invalid_similar_card');
              }
            }
            if (derivedIndex != null) {
              if (derivedIndex is! int ||
                  derivedIndex < 0 ||
                  derivedIndex >= derived[index].length) {
                throw PlatformException(code: 'invalid_derived_example');
              }
              audioUrl = derived[index][derivedIndex].example.audioUrl;
            }
            if (exampleIndex != null) {
              final examples = content.examples;
              if (exampleIndex is! int ||
                  exampleIndex < 0 ||
                  exampleIndex >= examples.length) {
                throw PlatformException(code: 'invalid_example');
              }
              audioUrl = examples[exampleIndex].audioUrl;
            }
            if (characterIndex != null) {
              if (exampleIndex != null ||
                  characterIndex is! int ||
                  characterIndex < 0 ||
                  characterIndex >= characters[index].length) {
                throw PlatformException(code: 'invalid_character');
              }
              audioUrl = characters[index][characterIndex].audioUrl;
            }
            if (audio == null || audioUrl == null || audioUrl.trim().isEmpty) {
              throw PlatformException(code: 'audio_unavailable');
            }
            return audio.fetch(audioUrl);
          }
          if (call.method == 'rate' && recall) {
            if (ratings.containsKey(index)) return null;
            if (index != ratings.length) {
              throw PlatformException(code: 'invalid_order');
            }
            final rating = args['correct'] == true
                ? CardRating.good
                : CardRating.again;
            final prompt = prompts[index].withCard(latest[queue[index].id]!);
            final time = DateTime.fromMillisecondsSinceEpoch(
              args['revealedAt'] as int,
              isUtc: true,
            );
            // Retry the exact review after a failed durable write; do not mint
            // another review ID or apply FSRS a second time.
            final updated = pendingOutcomes.putIfAbsent(
              index,
              () => scheduler.preview(prompt, time)[rating]!.card,
            );
            await library.saveSchedule(updated);
            pendingOutcomes.remove(index);
            ratings[index] = rating;
            latest[updated.id] = updated;
            if (mounted) ref.read(cardsInvalidationProvider)();
            return null;
          }
          throw PlatformException(code: 'unsupported_action');
        },
      );
    } finally {
      closed = true;
      preparations.close();
    }
    if (handled && recall && mounted) {
      var missed = retryRecallPrompts(prompts, ratings, latest);
      final action = await Navigator.of(context).push<Object?>(
        MaterialPageRoute<Object?>(
          builder: (recapContext) => RecallRecapPage(
            studyScope: widget.studyScope,
            onRepeatIncorrect: () {
              missed = retryRecallPrompts(prompts, ratings, latest);
              Navigator.pop(recapContext, RecallRecapAction.repeatIncorrect);
            },
            reviewedCount: ratings.length,
            totalCount: queue.length,
            missCount: ratings.values
                .where((r) => r == CardRating.again)
                .length,
            entries: [
              for (var i = 0; i < queue.length; i++)
                RecallRecapEntry(
                  card: latest[queue[i].id]!,
                  rating: ratings[i],
                ),
            ],
          ),
        ),
      );
      if (action == RecallRecapAction.repeatIncorrect &&
          mounted &&
          sessionKey ==
              ref.read(activeCardsSessionProvider).value?.account.key &&
          missed.isNotEmpty) {
        await _openNativeDrawing(prompts: missed);
      }
    }
    return handled;
  }

  Future<void> _startFastRecall() async {
    final prompts = await _latestSelectedPrompts();
    if (!mounted || prompts == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _withSessionSound(
          LanguageFastRecallPage(
            title: widget.title,
            prompts: prompts,
            studyScope: widget.studyScope,
          ),
        ),
      ),
    );
    await _refreshSetup();
  }

  Future<List<StudyPrompt>?> _latestSelectedPrompts({
    bool deferBodies = false,
  }) async {
    if (_starting || _cue == null) return null;
    setState(() => _starting = true);
    try {
      final dashboard = await ref.read(cardsDashboardProvider.future);
      _startupStep('dashboard_ready');
      final cardsById = <int, StudyCard>{
        for (final card in dashboard.cards) card.id: card,
      };
      final selected = <StudyPrompt>[
        for (final candidate in _candidates)
          if (cardsById[candidate.cardId] case final card?
              when !card.suspended && card.supportsCue(candidate.cue))
            candidate
                .withCard(card)
                .forRecall(writing: _mode != StudyMode.ai && _allowsWriting),
      ];

      if (selected.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isBookStudy || _usesRecallFilters
                    ? 'No cards match these filters'
                    : 'Nothing due right now',
              ),
            ),
          );
        }
        return null;
      }

      if (!_usesRecallFilters &&
          ((_isBookStudy && _mode != StudyMode.study) ||
              _order == StudyOrder.shuffle)) {
        selected.shuffle(Random.secure());
      }
      if (_usesRecallFilters) {
        prioritizeRecallPrompts(selected, DateTime.now().toUtc());
      }
      _startupStep('selection_ready');
      final chosen = shuffledRecallSelection(
        selected,
        _count,
        random: Random.secure(),
      );
      final bodies = deferBodies
          ? chosen.map((p) => p.card).toList()
          : await hydrateStudyQueue(
              chosen.map((prompt) => prompt.card).toList(),
              (card) => hydrateStudyCard(ref, card),
            );
      final hydrated = [
        for (var i = 0; i < chosen.length; i++)
          StudyPrompt(
            card: bodies[i],
            cue: chosen[i].cue,
            additionalCues: chosen[i].additionalCues,
            testScript: chosen[i].testScript,
            showEnglishAndTransliteration: _combinedPrompt,
          ),
      ];
      _startupStep('queue_hydrated count=${hydrated.length}');
      return hydrated;
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

  Future<void> _openStudySheet() async {
    final prompts = _practiceCandidates.toList();
    if (_order == StudyOrder.shuffle) prompts.shuffle(Random.secure());
    final chosen = takeRecallCards(prompts, _count);
    final selected = chosen.map((p) => p.card).toList();
    final hydrated = <StudyCard>[];
    try {
      for (final card in selected) {
        hydrated.add(await hydrateStudyCard(ref, card));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open study sheet: $error')),
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LanguageStudyPage(
          title: widget.title,
          cards: hydrated,
          cues: _isBookStudy ? null : chosen.map((p) => p.cue).toList(),
          itemLabel: _isBookStudy ? 'cards' : null,
        ),
      ),
    );
  }

  Future<void> _openDrawPractice() async {
    if (_starting) return;
    _beginStartup('drawing');
    setState(() => _starting = true);
    try {
      final dashboard = await ref.read(cardsDashboardProvider.future);
      _startupStep('dashboard_ready');
      final ids = _studyCards.map((card) => card.id).toSet();
      final candidates = [
        for (final card in dashboard.cards)
          if (ids.contains(card.id) &&
              card.isLanguageCard &&
              !card.spokenOnly &&
              !card.suspended &&
              _matchesRecallBaseFilters(card))
            for (final cue in selectedCues(
              card,
              _directions,
            ).where((c) => c.target == RecallComponent.script))
              if (card.supportsCue(cue)) StudyPrompt(card: card, cue: cue),
      ]..shuffle(Random.secure());
      final chosen = takeRecallCards(candidates, _count);
      final selected = chosen.map((p) => p.card).toList();
      if (selected.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cards match this selection')),
          );
        }
        return;
      }
      _startupStep('selection_ready');
      if (await _openNativeDrawing(cards: selected, practicePrompts: chosen)) {
        await _refreshSetup();
        return;
      }
      final hydrated = await hydrateStudyQueue(
        selected,
        (card) => hydrateStudyCard(ref, card),
      );
      if (!mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => ScriptDrawPracticePage(
            title: widget.title,
            cards: hydrated,
            cues: chosen.map((p) => p.cue).toList(),
            audioRepository: ref.read(cardAudioRepositoryProvider),
          ),
        ),
      );
      await _refreshSetup();
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
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => VoiceStudySessionPage(
          studyScope: widget.studyScope,
          title: widget.title,
          prompts: prompts,
          languages: _isBookStudy
              ? null
              : (from: widget.fromLanguage, to: widget.toLanguage),
        ),
      ),
    );
    await _refreshSetup();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(cardsDashboardProvider);
    ref.watch(reviewProgressionSettingsProvider);
    final maxCount = _availableCount;
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
                  Text(
                    widget.flow == StudySetupFlow.practice
                        ? 'PRACTICE'
                        : 'RECALL',
                    style: monoLabel,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.flow == StudySetupFlow.practice
                        ? 'How do you want to practice?'
                        : 'How do you want to recall?',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (widget.flow == StudySetupFlow.recall)
                    SegmentedButton<StudyMode>(
                      style: const ButtonStyle(
                        padding: WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: StudyMode.recall,
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Recall', maxLines: 1),
                          ),
                        ),
                        ButtonSegment(
                          value: StudyMode.ai,
                          icon: Icon(Icons.auto_awesome_outlined),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('AI', maxLines: 1),
                          ),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (value) => _selectMode(value.single),
                    ),
                  const SizedBox(height: 20),
                  if (_mode == StudyMode.study) ...[
                    if (!_isBookStudy) ...[
                      _SetupCard(
                        title: _selectionTitle,
                        trailing: _explicitDirections
                            ? _directionActions()
                            : null,
                        child: _directionChoices(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_supportsDrawing) ...[
                      _SetupCard(
                        title: 'Study format',
                        child: SegmentedButton<StudyPresentation>(
                          style: const ButtonStyle(
                            padding: WidgetStatePropertyAll(
                              EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: StudyPresentation.sheet,
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Study sheet', maxLines: 1),
                              ),
                            ),
                            ButtonSegment(
                              value: StudyPresentation.draw,
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Draw', maxLines: 1),
                              ),
                            ),
                          ],
                          selected: {_studyPresentation},
                          onSelectionChanged: (value) =>
                              _selectStudyPresentation(value.single),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!_supportsDrawing ||
                        _studyPresentation == StudyPresentation.sheet) ...[
                      _SetupCard(
                        title: 'How many cards?',
                        child: _countControl(maxCount),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: maxCount == 0 ? null : _openStudySheet,
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 13),
                          child: Text('Open study sheet'),
                        ),
                      ),
                    ] else ...[
                      _SetupCard(
                        title: 'How many cards?',
                        child: _countControl(maxCount),
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
                    ...[
                      _SetupCard(
                        title: 'Recall format',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final formats =
                                    SegmentedButton<RecallPresentation>(
                                      showSelectedIcon: false,
                                      style: const ButtonStyle(
                                        padding: WidgetStatePropertyAll(
                                          EdgeInsets.symmetric(horizontal: 8),
                                        ),
                                      ),
                                      segments: [
                                        const ButtonSegment(
                                          value: RecallPresentation.standard,
                                          label: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'Standard',
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                        const ButtonSegment(
                                          value: RecallPresentation.fast,
                                          label: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text('Fast', maxLines: 1),
                                          ),
                                        ),
                                      ],
                                      selected: {_recallPresentation},
                                      onSelectionChanged: (value) =>
                                          _selectRecallPresentation(
                                            value.single,
                                          ),
                                    );
                                final silent = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Silent'),
                                    const SizedBox(width: 12),
                                    Switch(
                                      key: const ValueKey('recall-silent'),
                                      value: _silent,
                                      onChanged: (value) {
                                        setState(() {
                                          _silent = value;
                                          _clampCount();
                                        });
                                        _rememberPreferences();
                                      },
                                    ),
                                  ],
                                );
                                return constraints.maxWidth >= 480
                                    ? Row(
                                        children: [
                                          SizedBox(
                                            width: constraints.maxWidth * 0.5,
                                            child: formats,
                                          ),
                                          const Spacer(),
                                          silent,
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          formats,
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: silent,
                                          ),
                                        ],
                                      );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    ...[
                      if (!_isBookStudy) ...[
                        _SetupCard(
                          title: _selectionTitle,
                          trailing: _explicitDirections
                              ? _directionActions()
                              : null,
                          child: _directionChoices(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _SetupCard(
                        title: 'Recall Cards By',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final timing = SegmentedButton<RecallTiming>(
                                  key: const ValueKey('recall-timing'),
                                  showSelectedIcon: false,
                                  segments: const [
                                    ButtonSegment(
                                      value: RecallTiming.allMatching,
                                      label: Text('Retention'),
                                    ),
                                    ButtonSegment(
                                      value: RecallTiming.dueNow,
                                      label: Text('Due'),
                                    ),
                                    ButtonSegment(
                                      value: RecallTiming.byDate,
                                      label: Text('Date'),
                                    ),
                                  ],
                                  selected: {_timing},
                                  onSelectionChanged: (value) {
                                    setState(() {
                                      _timing = value.single;
                                      if (_byDate &&
                                          _selectedDates.isEmpty &&
                                          _dateGroups.isNotEmpty) {
                                        _selectedDates = {
                                          _dateGroups.keys.first,
                                        };
                                      }
                                      _clampCount();
                                    });
                                    _rememberPreferences();
                                  },
                                );
                                if (_byDate || _dueOnly) return timing;
                                if (constraints.maxWidth >= 560) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: timing,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      _retentionShortcuts(),
                                    ],
                                  );
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    timing,
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: _retentionShortcuts(),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            if (_byDate)
                              _dateFilterChoices()
                            else if (_dueOnly)
                              _dueFilterChoices()
                            else
                              _recallFilterChoices(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SetupCard(
                        title: 'Cards (recalls)',
                        child: _countControl(maxCount),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _cue == null || maxCount == 0 || _starting
                          ? null
                          : _recallPresentation == RecallPresentation.fast
                          ? _startFastRecall
                          : _start,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Text('Start recall'),
                      ),
                    ),
                  ] else ...[
                    if (!_isBookStudy) ...[
                      _SetupCard(
                        title: _selectionTitle,
                        trailing: _explicitDirections
                            ? _directionActions()
                            : null,
                        child: _directionChoices(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    _SetupCard(
                      title: 'Retention',
                      child: _recallFilterChoices(),
                    ),
                    const SizedBox(height: 16),
                    _SetupCard(
                      title: 'Cards (recalls)',
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

  Widget _directionActions() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton(
        key: const ValueKey('recall-directions-all'),
        onPressed: () => _setRecallCues(StudyCue.languageDirections.toSet()),
        child: const Text('All'),
      ),
      TextButton(
        key: const ValueKey('recall-directions-clear'),
        onPressed: () => _setRecallCues({}),
        child: const Text('Clear'),
      ),
    ],
  );

  void _setRecallCues(Set<StudyCue> cues) {
    setState(() {
      _recallCues = cues;
      _clampCount();
    });
    _rememberPreferences();
  }

  Widget _directionChoices() => _explicitDirections
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecallDirectionChoices(
              selected: _recallCues,
              onChanged: (cues) {
                setState(() {
                  _recallCues = cues;
                  _clampCount();
                });
                _rememberPreferences();
              },
            ),
            if (!_wideRecall && _recallCues.isNotEmpty)
              _sessionOption(
                key: 'recall-writing',
                icon: Icons.edit_outlined,
                title: 'Writing',
                description: 'Test script recall and show the writing pad',
                value: _writing,
                onChanged: (value) => _writing = value,
              ),
          ],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DirectionChoices(
              frontOnly: _mode != StudyMode.study,
              language: widget.toLanguage,
              selected: _directions,
              allowed: _mode == StudyMode.ai
                  ? const [RecallComponent.meaning, RecallComponent.sound]
                  : RecallComponent.values,
              onChanged: (value) => setState(() {
                _directions = value;
                _clampCount();
              }),
            ),
            if (_mode == StudyMode.recall && _supportsDrawing) ...[
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _recallOptions(),
            ],
          ],
        );

  Widget _withSessionSound(Widget child) => ProviderScope(
    overrides: [
      if (!_sessionSound) cardAudioRepositoryProvider.overrideWithValue(null),
    ],
    child: child,
  );

  Widget _recallOptions() => Column(
    children: [
      _sessionOption(
        key: 'recall-writing',
        icon: Icons.edit_outlined,
        title: 'Writing',
        description: 'Script answers and space to write',
        value: _writing,
        onChanged: (value) => _writing = value,
      ),
      const SizedBox(height: 4),
    ],
  );

  Widget _sessionOption({
    required String key,
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile.adaptive(
    key: ValueKey(key),
    contentPadding: EdgeInsets.zero,
    secondary: Icon(
      icon,
      size: 22,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    title: Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(description, style: const TextStyle(fontSize: 12)),
    value: value,
    onChanged: (value) {
      setState(() {
        onChanged(value);
        _clampCount();
      });
      _rememberPreferences();
    },
  );

  Widget _dueFilterChoices() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$_dueMinPercentage–100%'),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colors.secondaryContainer,
            inactiveTrackColor: colors.primary,
            activeTickMarkColor: colors.secondaryContainer,
            inactiveTickMarkColor: colors.primary,
            thumbColor: colors.primary,
          ),
          child: Slider(
            key: const ValueKey('due-retention'),
            value: _dueMinPercentage.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            label: '$_dueMinPercentage–100%',
            onChanged: (value) {
              setState(() {
                _dueMinPercentage = value.round();
                _clampCount();
              });
              _rememberPreferences();
            },
          ),
        ),
      ],
    );
  }

  Widget _dateFilterChoices() {
    final dates = _dateGroups.keys.toList()..sort();
    if (dates.isEmpty) {
      return const Text(
        'No dated cards yet. Cards moved into Current from now on will appear here.',
      );
    }
    final selected = _dateRange;
    final start = dates.indexOf(selected.first);
    final end = dates.indexOf(selected.last);
    String label(String date) => MaterialLocalizations.of(
      context,
    ).formatMediumDate(DateTime.parse(date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          start == end
              ? label(dates[start])
              : '${label(dates[start])} – ${label(dates[end])}',
        ),
        RangeSlider(
          key: const ValueKey('recall-date-range'),
          min: 0,
          max: max(1, dates.length - 1).toDouble(),
          divisions: max(1, dates.length - 1),
          values: RangeValues(start.toDouble(), end.toDouble()),
          labels: RangeLabels(label(dates[start]), label(dates[end])),
          onChanged: dates.length == 1
              ? null
              : (range) {
                  setState(() {
                    _selectedDates = dates
                        .sublist(range.start.round(), range.end.round() + 1)
                        .toSet();
                    _clampCount();
                  });
                  _rememberPreferences();
                },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label(dates.first))),
            if (dates.length > 1)
              Expanded(
                child: Text(label(dates.last), textAlign: TextAlign.end),
              ),
          ],
        ),
      ],
    );
  }

  Widget _retentionShortcuts() => Wrap(
    children: [
      TextButton(
        onPressed: () => setState(() {
          _retainedMinPercentage = 0;
          _retainedMaxPercentage = 60;
          _weakOnly = true;
          _newOnly = false;
          _clampCount();
          _rememberPreferences();
        }),
        child: const Text('Weak'),
      ),
      TextButton(
        onPressed: () => setState(() {
          _retainedMinPercentage = 80;
          _retainedMaxPercentage = 100;
          _weakOnly = false;
          _newOnly = false;
          _clampCount();
          _rememberPreferences();
        }),
        child: const Text('Strong'),
      ),
      TextButton(
        onPressed: () => setState(() {
          _newOnly = true;
          _weakOnly = false;
          _retainedMinPercentage = 0;
          _retainedMaxPercentage = 100;
          _clampCount();
          _rememberPreferences();
        }),
        child: const Text('New'),
      ),
    ],
  );

  Widget _recallFilterChoices() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _newOnly
            ? 'New'
            : _weakOnly
            ? '0–60%'
            : '$_retainedMinPercentage–$_retainedMaxPercentage%',
      ),
      Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: RangeSlider(
              key: const ValueKey('recall-retention'),
              values: RangeValues(
                _retainedMinPercentage.toDouble(),
                _retainedMaxPercentage.toDouble(),
              ),
              labels: RangeLabels(
                '$_retainedMinPercentage%',
                '$_retainedMaxPercentage%',
              ),
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: _selectRetainedRange,
            ),
          ),
          if (_mode == StudyMode.ai) _retentionShortcuts(),
        ],
      ),
    ],
  );

  Widget _countControl(int maxCount) {
    final available = _availableCardCount;
    final noun = available == 1 ? 'card' : 'cards';
    final selectedRecalls = _displayCount.clamp(1, maxCount > 0 ? maxCount : 1);
    // Selection covers distinct cards before adding other cues for those cards.
    final selectedCards = min(selectedRecalls, available);
    return maxCount == 0
        ? Text(
            _dueOnly ? '0 cards due' : 'No cards match these filters',
            style: TextStyle(color: RecallColors.faint),
          )
        : Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _usesRecallFilters
                          ? '$selectedCards ($selectedRecalls)'
                          : '$selectedRecalls',
                      key: const ValueKey('selected-recall-count'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _usesRecallFilters
                          ? '$available $noun ($maxCount ${maxCount == 1 ? 'recall' : 'recalls'})'
                          : '$available $noun available',
                      key: const ValueKey('available-recall-count'),
                      style: const TextStyle(color: RecallColors.muted),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              Slider(
                key: const ValueKey('card-count'),
                value: _displayCount.clamp(1, maxCount).toDouble(),
                min: 1,
                max: maxCount.toDouble(),
                divisions: maxCount > 1 ? maxCount - 1 : null,
                onChanged: _selectCount,
              ),
            ],
          );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}
