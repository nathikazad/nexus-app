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
import 'package:nx_cards/browser/card_list/card_schedule_status.dart';
import 'package:nx_cards/study/language/language_study_page.dart';
import 'package:nx_cards/study/language/language_fast_recall_page.dart';
import 'package:nx_cards/study/language/drawing/script_draw_practice_page.dart';
import 'package:nx_cards/study/language/drawing/recall_interaction.dart';
import 'package:nx_cards/study/session/study_session_page.dart';
import 'package:nx_cards/tutor/voice_tutor_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StudyOrder { normal, shuffle }

enum StudyMode { study, recall, ai }

enum StudySourceKind { language, book }

enum StudyPresentation { sheet, draw }

enum RecallPresentation { standard, write, fast }

enum RecallCardState { learning, relearning, retained, newCard }

enum RecallTiming { allMatching, dueNow }

class StudySetupPage extends ConsumerStatefulWidget {
  const StudySetupPage({
    super.key,
    required this.title,
    required this.prompts,
    required this.studyCards,
    required this.fromLanguage,
    required this.toLanguage,
    this.preferenceKey,
    this.sourceKind = StudySourceKind.language,
  });

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
  StudyMode _mode = StudyMode.study;
  StudyPresentation _studyPresentation = StudyPresentation.sheet;
  RecallPresentation _recallPresentation = RecallPresentation.standard;
  StudyCue? _cue = StudyCue.fromLanguage;
  bool _combinedPrompt = false;

  List<StudyCard> get _studyCards {
    final latest = ref.read(cardsDashboardProvider).value?.cards;
    if (latest == null) return widget.studyCards;
    final ids = widget.studyCards.map((card) => card.id).toSet();
    return latest.where((card) => ids.contains(card.id)).toList();
  }

  final Set<LearningStatus> _learningStatuses = <LearningStatus>{
    LearningStatus.learning,
  };
  final Set<RecallCardState> _recallStates = RecallCardState.values.toSet();
  RecallTiming _recallTiming = RecallTiming.allMatching;
  int _retainedMaxPercentage = 100;
  RangeValues _bookRecallRange = const RangeValues(0, 100);
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
      final bookRecallMinimum = saved['bookRecallMinimum'];
      final bookRecallMaximum = saved['bookRecallMaximum'];
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
        _combinedPrompt =
            saved['combinedPrompt'] == true && _cue == StudyCue.fromLanguage;
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
        if (bookRecallMinimum is int && bookRecallMaximum is int) {
          _bookRecallRange = RangeValues(
            bookRecallMinimum.clamp(0, 100).toDouble(),
            bookRecallMaximum.clamp(0, 100).toDouble(),
          );
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
        'combinedPrompt': _combinedPrompt,
        'learningStatuses': [
          for (final status in _learningStatuses) status.name,
        ],
        'recallStates': [for (final state in _recallStates) state.name],
        'recallTiming': _recallTiming.name,
        'retainedMaxPercentage': _retainedMaxPercentage,
        'bookRecallMinimum': _bookRecallRange.start.round(),
        'bookRecallMaximum': _bookRecallRange.end.round(),
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
    if (_isBookStudy) return _bookCandidates;
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
      for (final card in _studyCards)
        if (!card.suspended &&
            card.scheduleFor(cue).enabled &&
            _matchesRecallBaseFilters(card))
          StudyPrompt(card: card, cue: cue),
    ];
  }

  bool _matchesRecallBaseFilters(StudyCard card) {
    final cue = _cue;
    if (cue == null) return false;
    final state = _recallState(card, cue);
    return _learningStatuses.contains(card.learningStatus) &&
        _recallStates.contains(state) &&
        (state != RecallCardState.retained ||
            cueRecallPercentage(
                  card,
                  cue,
                  historyWindow: _reviewHistoryWindow,
                ) <=
                _retainedMaxPercentage);
  }

  bool _matchesRecallFilters(StudyCard card) =>
      _matchesRecallBaseFilters(card) &&
      (_recallTiming == RecallTiming.allMatching || _isDueForRecall(card));

  bool _isDueForRecall(StudyCard card) {
    final cue = _cue;
    return cue != null && card.scheduleFor(cue).isDueAt(DateTime.now().toUtc());
  }

  RecallCardState _recallState(StudyCard card, StudyCue cue) {
    final schedule = card.scheduleFor(cue);
    if (schedule.lastReviewedAt == null) return RecallCardState.newCard;
    return switch (schedule.schedulingState) {
      'learning' => RecallCardState.learning,
      'relearning' => RecallCardState.relearning,
      _ => RecallCardState.retained,
    };
  }

  List<StudyCard> get _drawCandidates => _studyCards
      .where(
        (card) =>
            card.content is LanguageCardContent &&
            !card.suspended &&
            _matchesRecallFilters(card),
      )
      .toList(growable: false);

  List<StudyCard> get _studySheetCandidates => _studyCards
      .where(
        (card) =>
            card.content is LanguageCardContent &&
            !card.suspended &&
            _matchesRecallFilters(card),
      )
      .toList(growable: false);

  List<StudyPrompt> get _bookCandidates => <StudyPrompt>[
    for (final card in _studyCards)
      if (!card.suspended &&
          card.scheduleFor(StudyCue.fromLanguage).enabled &&
          _matchesBookRecallRange(card))
        StudyPrompt(card: card, cue: StudyCue.fromLanguage),
  ];

  bool _matchesBookRecallRange(StudyCard card) {
    final recall = cardRecallPercentage(
      card,
      historyWindow: _reviewHistoryWindow,
    );
    return recall >= _bookRecallRange.start && recall <= _bookRecallRange.end;
  }

  int get _availableCount => _isBookStudy
      ? _bookCandidates.length
      : _mode == StudyMode.study && _studyPresentation == StudyPresentation.draw
      ? _drawCandidates.length
      : _mode == StudyMode.study
      ? _studySheetCandidates.length
      : _candidates.length;

  bool get _usesRecallFilters =>
      _mode == StudyMode.recall || _mode == StudyMode.ai;

  int get _reviewHistoryWindow =>
      ref.read(reviewProgressionSettingsProvider).value?.historyWindow ?? 5;

  bool get _supportsDrawing =>
      !_isBookStudy &&
      _studyCards.isNotEmpty &&
      _studyCards.every((card) => card.isLanguageCard);

  String get _selectionTitle => 'Which cards?';

  bool get _isBookStudy => widget.sourceKind == StudySourceKind.book;

  String _cueLabel(StudyCue cue) => switch (cue) {
    StudyCue.fromLanguage =>
      widget.fromLanguage == 'Front' ? 'English' : widget.fromLanguage,
    StudyCue.toLanguage => widget.toLanguage,
    StudyCue.transliteration => 'Transliteration',
  };

  void _selectCue(StudyCue cue) {
    setState(() {
      _cue = cue;
      _combinedPrompt = false;
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

  bool get _allRecallStatesSelected =>
      _recallStates.length == RecallCardState.values.length;

  void _toggleRecallState(RecallCardState state) {
    setState(() {
      if (_allRecallStatesSelected) {
        _recallStates
          ..clear()
          ..add(state);
      } else if (_recallStates.contains(state)) {
        if (_recallStates.length > 1) _recallStates.remove(state);
      } else {
        _recallStates.add(state);
      }
      _resetCount();
    });
    _rememberPreferences();
  }

  void _selectAllRecallStates() {
    setState(() {
      _recallStates
        ..clear()
        ..addAll(RecallCardState.values);
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

  void _selectBookRecallRange(RangeValues range) {
    setState(() {
      _bookRecallRange = range;
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

  void _selectCount(double count) {
    setState(() => _count = count.round());
    _rememberPreferences();
  }

  Future<void> _refreshSetup() async {
    if (!mounted) return;
    try {
      await ref.read(cardsDashboardProvider.future);
      if (!mounted) return;
      setState(() => _count = _count.clamp(1, max(1, _availableCount)));
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
    final prompts = await _latestSelectedPrompts();
    if (!mounted || prompts == null) return;
    if (_recallPresentation == RecallPresentation.write &&
        prompts.every((p) => p.card.content is LanguageCardContent)) {
      if (await _openNativeDrawing(prompts: prompts)) {
        await _refreshSetup();
        return;
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StudySessionPage(
          title: widget.title,
          prompts: prompts,
          interaction: _recallPresentation == RecallPresentation.write
              ? RecallInteraction.writing
              : RecallInteraction.standard,
        ),
      ),
    );
    await _refreshSetup();
  }

  Future<bool> _openNativeDrawing({
    List<StudyCard>? cards,
    List<StudyPrompt>? prompts,
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
    final linkedLibrary = {
      for (final card in await library.listCards()) card.id: card,
    };
    _startupStep('library_loaded count=${linkedLibrary.length}');
    await NativeDrawingSession.hydrateExampleParents(
      queue,
      linkedLibrary,
      (card) => hydrateStudyCard(ref, card),
    );
    _startupStep('example_parents_hydrated');
    if (!mounted ||
        sessionKey != ref.read(activeCardsSessionProvider).value?.account.key) {
      return true;
    }
    final characters = [
      for (final card in queue)
        NativeDrawingSession.characterParts(card, linkedLibrary),
    ];
    final derived = [
      for (final card in queue)
        NativeDrawingSession.derivedExamples(card, linkedLibrary),
    ];
    _startupStep('context_derived');
    final handled = await NativeDrawingSession.open(
      title: widget.title,
      cards: recall
          ? [
              for (var i = 0; i < prompts.length; i++)
                NativeDrawingSession.recallCard(
                  prompts[i],
                  characters: characters[i],
                  derived: derived[i],
                ),
            ]
          : [
              for (var i = 0; i < queue.length; i++)
                NativeDrawingSession.practiceCard(
                  queue[i],
                  characters: characters[i],
                  derived: derived[i],
                ),
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
        if (call.method == 'exampleCard') {
          if (recall) {
            throw PlatformException(code: 'navigation_disabled_in_recall');
          }
          final targetId = args['cardId'];
          final parent = queue[index].content as LanguageCardContent;
          final permitted = {
            ...parent.examples.map((e) => e.cardId),
            ...derived[index].map((e) => e.example.cardId),
          };
          final target = targetId is int ? linkedLibrary[targetId] : null;
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
          if ([
                exampleIndex,
                characterIndex,
                derivedIndex,
              ].where((v) => v != null).length >
              1) {
            throw PlatformException(code: 'invalid_audio_target');
          }
          var audioUrl = content.audioUrl;
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
          final updated = scheduler.preview(prompt, time)[rating]!.card;
          await library.saveSchedule(updated);
          ratings[index] = rating;
          latest[updated.id] = updated;
          if (mounted) ref.read(cardsInvalidationProvider)();
          return null;
        }
        throw PlatformException(code: 'unsupported_action');
      },
    );
    if (handled && recall && mounted) {
      var missed = incorrectRecallPrompts(prompts, ratings, latest);
      final action = await Navigator.of(context).push<Object?>(
        MaterialPageRoute<Object?>(
          builder: (recapContext) => RecallRecapPage(
            onRepeatIncorrect: (changes) {
              for (final change in changes) {
                final card = latest[change.card.id];
                if (card != null) {
                  latest[card.id] = card.copyWith(
                    learningStatus: change.status,
                  );
                }
              }
              missed = incorrectRecallPrompts(prompts, ratings, latest);
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
        builder: (_) =>
            LanguageFastRecallPage(title: widget.title, prompts: prompts),
      ),
    );
    await _refreshSetup();
  }

  Future<List<StudyPrompt>?> _latestSelectedPrompts() async {
    if (_starting || _cue == null) return null;
    setState(() => _starting = true);
    try {
      final dashboard = await ref.read(cardsDashboardProvider.future);
      _startupStep('dashboard_ready');
      final cardsById = <int, StudyCard>{
        for (final card in dashboard.cards) card.id: card,
      };
      final selected =
          <StudyPrompt>[
                for (final queued in _candidates)
                  if (cardsById[queued.cardId] case final latestCard?
                      when !latestCard.suspended &&
                          (!_isBookStudy ||
                              _matchesBookRecallRange(latestCard)) &&
                          (!_usesRecallFilters ||
                              _matchesRecallFilters(latestCard)) &&
                          latestCard.scheduleFor(queued.cue).enabled)
                    StudyPrompt(card: latestCard, cue: queued.cue),
              ]
              .where(
                (prompt) =>
                    _isBookStudy ||
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
                _isBookStudy || _usesRecallFilters
                    ? 'No cards match these filters'
                    : 'Nothing due right now',
              ),
            ),
          );
        }
        return null;
      }

      if ((_isBookStudy && _mode != StudyMode.study) ||
          _usesRecallFilters ||
          _order == StudyOrder.shuffle) {
        selected.shuffle(Random.secure());
      }
      _startupStep('selection_ready');
      final hydrated = <StudyPrompt>[];
      for (final prompt in selected.take(min(_count, selected.length))) {
        hydrated.add(
          StudyPrompt(
            card: await hydrateStudyCard(ref, prompt.card),
            cue: prompt.cue,
            showEnglishAndTransliteration: _combinedPrompt,
          ),
        );
      }
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
    final cards =
        (_isBookStudy
                ? _bookCandidates.map((prompt) => prompt.card)
                : _studySheetCandidates)
            .toList(growable: true);
    if (_order == StudyOrder.shuffle) cards.shuffle(Random.secure());
    final selected = cards
        .take(min(_count, cards.length))
        .toList(growable: false);
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
      final eligibleIds = _studyCards.map((card) => card.id).toSet();
      final cards = dashboard.cards
          .where(
            (card) =>
                eligibleIds.contains(card.id) &&
                card.content is LanguageCardContent &&
                !card.suspended &&
                _matchesRecallFilters(card),
          )
          .toList(growable: true);
      cards.shuffle(Random.secure());
      final selected = cards
          .take(min(_count, cards.length))
          .toList(growable: false);
      if (selected.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cards match this selection')),
          );
        }
        return;
      }
      final hydrated = <StudyCard>[];
      for (final card in selected) {
        hydrated.add(await hydrateStudyCard(ref, card));
      }
      _startupStep('queue_hydrated count=${hydrated.length}');
      if (!mounted) return;
      if (await _openNativeDrawing(cards: hydrated)) {
        await _refreshSetup();
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => ScriptDrawPracticePage(
            title: widget.title,
            cards: hydrated,
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
                    style: const ButtonStyle(
                      padding: WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: StudyMode.study,
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Study', maxLines: 1),
                        ),
                      ),
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
                  const SizedBox(height: 28),
                  if (_isBookStudy) ...[
                    _SetupCard(
                      number: '01',
                      title: 'Recall percentage',
                      child: _bookRecallRangeControl(),
                    ),
                    const SizedBox(height: 14),
                    _SetupCard(
                      number: '02',
                      title: 'How many cards?',
                      child: _countControl(maxCount),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: maxCount == 0 || _starting
                          ? null
                          : switch (_mode) {
                              StudyMode.study => _openStudySheet,
                              StudyMode.recall => _start,
                              StudyMode.ai => _startAiTutor,
                            },
                      icon: Icon(switch (_mode) {
                        StudyMode.study => Icons.menu_book_outlined,
                        StudyMode.recall => Icons.play_arrow_rounded,
                        StudyMode.ai => Icons.record_voice_over_outlined,
                      }),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Text(switch (_mode) {
                          StudyMode.study => 'Open study sheet',
                          StudyMode.recall => 'Start recall',
                          StudyMode.ai => 'Start AI tutor',
                        }),
                      ),
                    ),
                  ] else if (_mode == StudyMode.study) ...[
                    if (_supportsDrawing) ...[
                      _SetupCard(
                        number: '01',
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
                      const SizedBox(height: 14),
                    ],
                    if (!_supportsDrawing ||
                        _studyPresentation == StudyPresentation.sheet) ...[
                      _SetupCard(
                        number: _supportsDrawing ? '02' : '01',
                        title: _selectionTitle,
                        child: _recallFilterChoices(),
                      ),
                      const SizedBox(height: 14),
                      _SetupCard(
                        number: _supportsDrawing ? '03' : '02',
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
                        number: '02',
                        title: _selectionTitle,
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
                        number: '01',
                        title: 'Recall format',
                        child: SegmentedButton<RecallPresentation>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            padding: WidgetStatePropertyAll(
                              EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                          segments: const [
                            ButtonSegment(
                              value: RecallPresentation.standard,
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Standard', maxLines: 1),
                              ),
                            ),
                            ButtonSegment(
                              value: RecallPresentation.write,
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Write', maxLines: 1),
                              ),
                            ),
                            ButtonSegment(
                              value: RecallPresentation.fast,
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Fast', maxLines: 1),
                              ),
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
                      number: '02',
                      title: 'What should be in front?',
                      child: _cueChoices(),
                    ),
                    const SizedBox(height: 14),
                    _SetupCard(
                      number: '03',
                      title: _selectionTitle,
                      child: _recallFilterChoices(),
                    ),
                    const SizedBox(height: 14),
                    _SetupCard(
                      number: '04',
                      title: 'How many cards?',
                      child: _countControl(maxCount),
                    ),
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
                        child: Text(
                          _recallPresentation == RecallPresentation.fast
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
                      title: _selectionTitle,
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
      for (final cue in StudyCue.values)
        ChoiceChip(
          label: Text(_cueLabel(cue)),
          selected: _cue == cue && !_combinedPrompt,
          onSelected: (_) => _selectCue(cue),
        ),
      ChoiceChip(
        label: const Text('Eng. + Transli.'),
        selected: _combinedPrompt,
        onSelected: (_) {
          setState(() {
            _cue = StudyCue.fromLanguage;
            _combinedPrompt = true;
            _resetCount();
          });
          _rememberPreferences();
        },
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
          FilterChip(
            label: const Text('All'),
            selected: _allRecallStatesSelected,
            onSelected: (_) => _selectAllRecallStates(),
          ),
          for (final state in RecallCardState.values)
            FilterChip(
              label: Text(switch (state) {
                RecallCardState.learning => 'Learning',
                RecallCardState.relearning => 'Relearning',
                RecallCardState.retained => 'Retained',
                RecallCardState.newCard => 'New',
              }),
              selected:
                  !_allRecallStatesSelected && _recallStates.contains(state),
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
          divisions: 10,
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
        style: const ButtonStyle(
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
        ),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: RecallTiming.allMatching,
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('All', maxLines: 1),
            ),
          ),
          ButtonSegment(
            value: RecallTiming.dueNow,
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Due', maxLines: 1),
            ),
          ),
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

  Widget _bookRecallRangeControl() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Text(
            '${_bookRecallRange.start.round()}–${_bookRecallRange.end.round()}%',
            key: const ValueKey('book-recall-range'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            '${_bookCandidates.length} matching',
            style: const TextStyle(color: RecallColors.muted),
          ),
        ],
      ),
      RangeSlider(
        key: const ValueKey('book-recall-slider'),
        values: _bookRecallRange,
        min: 0,
        max: 100,
        divisions: _reviewHistoryWindow,
        labels: RangeLabels(
          '${_bookRecallRange.start.round()}%',
          '${_bookRecallRange.end.round()}%',
        ),
        onChanged: _selectBookRecallRange,
      ),
      Text(
        'Successes across the last $_reviewHistoryWindow review slots',
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
