import 'package:nx_cards/scheduling/learning_stage.dart';
import 'package:nx_cards/scheduling/language_direction.dart';
import 'package:nx_cards/scheduling/study_scope.dart';
import 'package:nx_cards/study/lazy_study_queue.dart';
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
    this.studyScope,
    super.key,
    required this.title,
    required this.prompts,
    required this.studyCards,
    required this.fromLanguage,
    required this.toLanguage,
    this.preferenceKey,
    this.sourceKind = StudySourceKind.language,
  });

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
  StudyMode _mode = StudyMode.study;
  StudyPresentation _studyPresentation = StudyPresentation.sheet;
  RecallPresentation _recallPresentation = RecallPresentation.standard;
  StudyCue? get _cue => _isBookStudy
      ? StudyCue.fromLanguage
      : ref.read(
          languageDirectionProvider(
            widget.studyScope?.language ?? widget.toLanguage,
          ),
        );
  final bool _combinedPrompt = false;

  List<StudyCard> get _studyCards {
    final latest = ref.read(cardsDashboardProvider).value?.cards;
    if (latest == null) return widget.studyCards;
    final ids = widget.studyCards.map((card) => card.id).toSet();
    return latest.where((card) => ids.contains(card.id)).toList();
  }

  final Set<LearningStage> _learningStatuses = <LearningStage>{
    LearningStage.upcoming,
    LearningStage.current,
    LearningStage.past,
  };
  int _retainedMaxPercentage = 100;
  RangeValues _bookRecallRange = const RangeValues(0, 100);
  StudyOrder _order = StudyOrder.normal;
  int _count = 10;
  bool _starting = false;
  int _preferenceRevision = 0;

  String get _storedPreferenceKey =>
      'study_setup.v2.${widget.preferenceKey ?? widget.title}';

  @override
  void initState() {
    super.initState();
    _clampCount();
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
      final order = _enumByName(StudyOrder.values, saved['order']);
      final retainedMaxPercentage = saved['retainedMaxPercentage'];
      final bookRecallMinimum = saved['bookRecallMinimum'];
      final bookRecallMaximum = saved['bookRecallMaximum'];
      final statuses = saved['learningStatuses'] is List
          ? (saved['learningStatuses'] as List)
                .map((value) => _enumByName(LearningStage.values, value))
                .whereType<LearningStage>()
                .toSet()
          : const <LearningStage>{};
      setState(() {
        if (mode != null) _mode = mode;
        if (studyPresentation != null) {
          _studyPresentation = studyPresentation;
        }
        if (recallPresentation != null) {
          _recallPresentation = recallPresentation;
        }

        if (order != null) _order = order;
        if (statuses.isNotEmpty) {
          _learningStatuses
            ..clear()
            ..addAll(statuses);
        }
        if (retainedMaxPercentage is int) {
          _retainedMaxPercentage = retainedMaxPercentage.clamp(0, 100);
        }
        if (bookRecallMinimum is int && bookRecallMaximum is int) {
          _bookRecallRange = RangeValues(
            bookRecallMinimum.clamp(0, 100).toDouble(),
            bookRecallMaximum.clamp(0, 100).toDouble(),
          );
        }
        final savedCount = saved['count'];
        _count = savedCount is int ? max(1, savedCount) : 10;
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
        'learningStatuses': [
          for (final status in _learningStatuses) status.name,
        ],
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
          .where((prompt) => _isDueForRecall(prompt.card))
          .toList(growable: false);
    }
    return _recallBaseCandidates;
  }

  List<StudyPrompt> get _recallBaseCandidates {
    final cue = _cue;
    if (cue == null) return const <StudyPrompt>[];
    final sorted = sortCardsByScheduleState(
      _studyCards,
      DateTime.now(),
      historyWindow: _reviewHistoryWindow,
      cue: cue,
    );
    return <StudyPrompt>[
      for (final card in sorted)
        if (!card.suspended &&
            card.scheduleFor(cue).enabled &&
            _matchesRecallBaseFilters(card))
          StudyPrompt(card: card, cue: cue),
    ];
  }

  bool _matchesRecallBaseFilters(StudyCard card) {
    final cue = _cue;
    if (cue == null) return false;
    return card.active &&
        _learningStatuses.contains(
          learningStage(card, cue, window: _reviewHistoryWindow),
        ) &&
        cueRecallPercentage(card, cue, historyWindow: _reviewHistoryWindow) <=
            _retainedMaxPercentage;
  }

  bool _matchesRecallFilters(StudyCard card) =>
      _matchesRecallBaseFilters(card) &&
      (!_usesRecallFilters || _isDueForRecall(card));

  bool _isDueForRecall(StudyCard card) =>
      _cue != null &&
      availableForRecall(
        card,
        _cue!,
        DateTime.now().toUtc(),
        window: _reviewHistoryWindow,
      );

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
          card.active &&
          (!_usesRecallFilters ||
              availableForRecall(
                card,
                StudyCue.fromLanguage,
                DateTime.now(),
                window: _reviewHistoryWindow,
              )) &&
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
      ref.read(reviewProgressionSettingsProvider).value?.historyWindow ?? 10;

  bool get _supportsDrawing =>
      !_isBookStudy &&
      _studyCards.isNotEmpty &&
      _studyCards.every((card) => card.isLanguageCard);

  String get _selectionTitle => 'Which cards?';

  bool get _isBookStudy => widget.sourceKind == StudySourceKind.book;

  void _toggleLearningStatus(LearningStage status) {
    setState(() {
      if (_learningStatuses.contains(status)) {
        if (_learningStatuses.length > 1) _learningStatuses.remove(status);
      } else {
        _learningStatuses.add(status);
      }
      _clampCount();
    });
    _rememberPreferences();
  }

  void _selectRetainedMaxPercentage(double percentage) {
    setState(() {
      _retainedMaxPercentage = percentage.round();
      _clampCount();
    });
    _rememberPreferences();
  }

  void _selectBookRecallRange(RangeValues range) {
    setState(() {
      _bookRecallRange = range;
      _clampCount();
    });
    _rememberPreferences();
  }

  void _clampCount() {
    final available = _availableCount;
    if (available > 0) _count = _count.clamp(1, available);
  }

  void _selectMode(StudyMode mode) {
    setState(() {
      _mode = mode;
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
          _recallPresentation == RecallPresentation.write &&
          await NativeDrawingSession.isAvailable(),
    );
    if (!mounted || prompts == null) return;
    if (_recallPresentation == RecallPresentation.write &&
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
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StudySessionPage(
          studyScope: widget.studyScope,
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
      for (final card in (await ref.read(cardsDashboardProvider.future)).cards)
        card.id: card,
    };
    _startupStep('library_snapshot count=${linkedLibrary.length}');
    final characters = List<List<LanguageCardContent>>.generate(
      queue.length,
      (_) => [],
    );
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
      characters[index] = NativeDrawingSession.characterParts(
        full,
        linkedLibrary,
      );
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
              characters: characters[index],
              derived: derived[index],
            )
          : NativeDrawingSession.practiceCard(
              full,
              characters: characters[index],
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
    } finally {
      closed = true;
      preparations.close();
    }
    if (handled && recall && mounted) {
      var missed = incorrectRecallPrompts(prompts, ratings, latest);
      final action = await Navigator.of(context).push<Object?>(
        MaterialPageRoute<Object?>(
          builder: (recapContext) => RecallRecapPage(
            studyScope: widget.studyScope,
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
        builder: (_) => LanguageFastRecallPage(
          title: widget.title,
          prompts: prompts,
          studyScope: widget.studyScope,
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
      if (_usesRecallFilters && !_isBookStudy) {
        selected.sort((a, b) {
          final sa = learningStage(a.card, a.cue, window: _reviewHistoryWindow);
          final sb = learningStage(b.card, b.cue, window: _reviewHistoryWindow);
          final byStage = sa.index.compareTo(sb.index);
          if (byStage != 0) return byStage;
          if (sa != LearningStage.past) return 0;
          return recalledAnswers(
            a.card,
            a.cue,
            _reviewHistoryWindow,
          ).compareTo(recalledAnswers(b.card, b.cue, _reviewHistoryWindow));
        });
      }
      _startupStep('selection_ready');
      final chosen = selected.take(min(_count, selected.length)).toList();
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
      _startupStep('selection_ready');
      if (await _openNativeDrawing(cards: selected)) {
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
                          child: Text('Practice', maxLines: 1),
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
                      title: _selectionTitle,
                      child: _recallFilterChoices(),
                    ),
                    const SizedBox(height: 14),
                    _SetupCard(
                      number: '02',
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

  Widget _learningStatusChoices() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final stage in [
        LearningStage.upcoming,
        LearningStage.current,
        LearningStage.past,
      ])
        FilterChip(
          label: Text(stage.label),
          selected: _learningStatuses.contains(stage),
          onSelected: (_) => _toggleLearningStatus(stage),
        ),
    ],
  );

  Widget _recallFilterChoices() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _learningStatusChoices(),
      const SizedBox(height: 16),
      Text('Recall score: 0–$_retainedMaxPercentage%'),
      Slider(
        value: _retainedMaxPercentage.toDouble(),
        min: 0,
        max: 100,
        divisions: 10,
        onChanged: _selectRetainedMaxPercentage,
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
    ],
  );

  Widget _countControl(int maxCount) => maxCount == 0
      ? const Text(
          'No cards match these filters',
          style: TextStyle(color: RecallColors.faint),
        )
      : Column(
          children: [
            Row(
              children: [
                Text(
                  '${_count.clamp(1, maxCount)}',
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
              key: const ValueKey('card-count'),
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
