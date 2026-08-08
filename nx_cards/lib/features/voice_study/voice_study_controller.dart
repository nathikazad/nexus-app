import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:nx_live_agent/nx_live_agent.dart';

import '../../domain/card/cards_repository.dart';
import '../../domain/cards_models.dart';
import '../../domain/scheduling/card_scheduler.dart';

enum VoiceStudyPhase {
  idle,
  connecting,
  listening,
  thinking,
  speaking,
  paused,
  completed,
  error,
}

typedef VoiceStudyDeckLanguages = ({String? from, String? to});

class VoiceStudyController extends ChangeNotifier {
  factory VoiceStudyController({
    required LiveAgentSession session,
    required CardsRepository repository,
    required CardScheduler scheduler,
    required List<StudyPrompt> prompts,
    required Map<int, VoiceStudyDeckLanguages> deckLanguages,
    required VoidCallback onScheduleSaved,
    DateTime Function()? now,
  }) => VoiceStudyController._(
    session,
    repository,
    scheduler,
    prompts,
    deckLanguages,
    onScheduleSaved,
    now ?? DateTime.now,
  );

  VoiceStudyController._(
    this._session,
    this._repository,
    this._scheduler,
    List<StudyPrompt> prompts,
    Map<int, VoiceStudyDeckLanguages> deckLanguages,
    this._onScheduleSaved,
    this._now,
  ) : _prompts = List<StudyPrompt>.of(prompts),
      _deckLanguages = Map<int, VoiceStudyDeckLanguages>.of(deckLanguages) {
    _session.addListener(_syncSession);
  }

  final LiveAgentSession _session;
  final CardsRepository _repository;
  final CardScheduler _scheduler;
  final List<StudyPrompt> _prompts;
  final Map<int, VoiceStudyDeckLanguages> _deckLanguages;
  final VoidCallback _onScheduleSaved;
  final DateTime Function() _now;

  int _index = 0;
  int _reviewedCount = 0;
  int _correctCount = 0;
  int _partialCount = 0;
  int _incorrectCount = 0;
  bool _currentCardAssessed = false;
  bool _completed = false;
  CardRating? _assessmentRating;
  String _heard = '';
  String _feedback = '';

  int get index => _index;
  int get total => _prompts.length;
  int get reviewedCount => _reviewedCount;
  int get correctCount => _correctCount;
  int get partialCount => _partialCount;
  int get incorrectCount => _incorrectCount;
  bool get currentCardAssessed => _currentCardAssessed;
  CardRating? get assessmentRating => _assessmentRating;
  bool get isMuted => _session.muted;
  bool get muted => isMuted;
  String get transcript => _session.transcript;
  String get userTranscript => _session.latestUserTranscript;
  String get assistantTranscript => _session.latestAssistantTranscript;
  String get heard => _heard;
  String get feedback => _feedback;
  String? get error => _session.error;
  StudyPrompt? get currentPrompt =>
      _index < _prompts.length ? _prompts[_index] : null;
  double get progress =>
      total == 0 ? 0 : (_index + (_currentCardAssessed ? 1 : 0)) / total;
  LiveAgentUsage get usage => _session.usage;
  double get inputCost => _gptRealtimeInputCost(usage);
  double get outputCost => _gptRealtimeOutputCost(usage);
  double get totalCost => inputCost + outputCost;

  VoiceStudyPhase get phase {
    if (_completed) return VoiceStudyPhase.completed;
    return switch (_session.phase) {
      LiveAgentPhase.idle => VoiceStudyPhase.idle,
      LiveAgentPhase.connecting => VoiceStudyPhase.connecting,
      LiveAgentPhase.listening => VoiceStudyPhase.listening,
      LiveAgentPhase.thinking => VoiceStudyPhase.thinking,
      LiveAgentPhase.speaking => VoiceStudyPhase.speaking,
      LiveAgentPhase.paused => VoiceStudyPhase.paused,
      LiveAgentPhase.closed => VoiceStudyPhase.idle,
      LiveAgentPhase.error => VoiceStudyPhase.error,
    };
  }

  Future<void> start(LiveAgentCredentialProvider credentials) async {
    if (_prompts.isEmpty) {
      _completed = true;
      notifyListeners();
      return;
    }

    await _session.start(
      credentialProvider: credentials,
      spec: LiveAgentSpec(
        instructions: _instructions,
        initialContext: _contextForCurrentCard(firstCard: true),
      ),
      tools: _tools,
    );
  }

  List<LiveAgentTool> get _tools => [
    CallbackLiveAgentTool(
      definition: const LiveAgentToolDefinition(
        name: 'assess_current_card',
        description:
            'Save the learner assessment for the current card. This does not '
            'advance to another card.',
        parameters: {
          'type': 'object',
          'properties': {
            'rating': {
              'type': 'string',
              'enum': ['again', 'hard', 'good'],
              'description':
                  'again for unknown or wrong, hard for partial or hesitant, '
                  'good for a confident correct answer.',
            },
            'heard': {
              'type': 'string',
              'description': 'A concise transcript of the learner answer.',
            },
            'feedback': {
              'type': 'string',
              'description': 'One short sentence explaining the assessment.',
            },
          },
          'required': ['rating', 'heard', 'feedback'],
          'additionalProperties': false,
        },
      ),
      onInvoke: _assessCurrentCard,
    ),
    CallbackLiveAgentTool(
      definition: const LiveAgentToolDefinition(
        name: 'get_current_examples',
        description:
            'Get the stored examples for the current card when the learner '
            'asks for examples or usage.',
        parameters: {
          'type': 'object',
          'properties': <String, Object?>{},
          'additionalProperties': false,
        },
      ),
      onInvoke: _getCurrentExamples,
    ),
    CallbackLiveAgentTool(
      definition: const LiveAgentToolDefinition(
        name: 'advance_card',
        description:
            'Advance only after the learner explicitly asks to move on. The '
            'current card must already have been assessed.',
        parameters: {
          'type': 'object',
          'properties': <String, Object?>{},
          'additionalProperties': false,
        },
      ),
      onInvoke: _advanceCard,
    ),
  ];

  String get _instructions => '''
You are a concise, encouraging spoken language flashcard tutor.
The current card context supplies the deck and language.

For every card:
1. Ask the supplied question without revealing the answer first. Follow the
   supplied question_instruction, which accounts for the selected cue and the
   deck's source and target languages.
2. Listen to the learner. If they answer, say they do not know, or give up, call
   assess_current_card exactly once. Use again for unknown/wrong, hard for a
   partially correct or hesitant answer, and good for a confident correct one.
3. After assessment, teach or confirm the authoritative answer returned by the
   tool. Do not invent a spelling or transliteration.
   Say the answer only once. Treat pronunciation_hint and stored example
   transliterations as silent pronunciation aids. Never read a Malayalam word
   and then repeat its transliteration unless the learner explicitly asks for
   the transliteration.
4. Stay anchored to the same card for follow-up questions. If asked for examples
   or usage, call get_current_examples and use only those stored examples.
5. Call advance_card only when the learner explicitly says to move on, next,
   continue, or an unmistakable equivalent. Never advance merely because an
   answer was assessed.
6. If advance_card says the card is not assessed, obtain an answer or explicit
   admission first and assess it.

Keep spoken responses short unless the learner asks for more detail.
''';

  Future<LiveAgentToolResult> _assessCurrentCard(
    Map<String, Object?> arguments,
  ) async {
    final prompt = currentPrompt;
    if (prompt == null) {
      return const LiveAgentToolResult({
        'ok': false,
        'reason': 'no_current_card',
      });
    }
    if (_currentCardAssessed) {
      return LiveAgentToolResult({
        'ok': true,
        'saved': false,
        'reason': 'already_assessed',
        ..._answerPayload(prompt),
      });
    }

    final rating = cardRatingForTutorResult(arguments['rating']?.toString());
    final reviewedAt = _now().toUtc();
    final updated = _scheduler.preview(prompt, reviewedAt)[rating]!.card;
    await _repository.saveSchedule(updated);

    _replaceCard(prompt.card.id, updated);
    _assessmentRating = rating;
    _heard = arguments['heard']?.toString().trim() ?? '';
    _feedback = arguments['feedback']?.toString().trim() ?? '';
    _currentCardAssessed = true;
    _reviewedCount += 1;
    switch (rating) {
      case CardRating.again:
        _incorrectCount += 1;
      case CardRating.hard:
        _partialCount += 1;
      case CardRating.good || CardRating.easy:
        _correctCount += 1;
    }
    _onScheduleSaved();
    notifyListeners();

    return LiveAgentToolResult({
      'ok': true,
      'saved': true,
      'rating': rating.name,
      'feedback': _feedback,
      ..._answerPayload(currentPrompt!),
      'instruction':
          'Say the answer once, using pronunciation_hint silently. Do not '
          'repeat the transliteration unless asked. Then remain on this card '
          'for follow-ups.',
    });
  }

  LiveAgentToolResult _getCurrentExamples(Map<String, Object?> _) {
    final prompt = currentPrompt;
    if (prompt == null) {
      return const LiveAgentToolResult({
        'ok': false,
        'reason': 'no_current_card',
      });
    }
    final content = _languageContent(prompt);
    return LiveAgentToolResult({
      'ok': true,
      ..._answerPayload(prompt),
      'examples': (content?.examples ?? const <LanguageExample>[])
          .map(
            (example) => {
              'text': example.text,
              'transliteration': example.transliteration,
              'translation': example.translation,
            },
          )
          .toList(growable: false),
      'instruction':
          'Explain only the stored examples relevant to the question.',
    });
  }

  LiveAgentToolResult _advanceCard(Map<String, Object?> _) {
    if (!_currentCardAssessed) {
      return const LiveAgentToolResult({
        'ok': false,
        'reason': 'current_card_not_assessed',
        'instruction':
            'Do not advance. Ask for an answer or whether the learner gives up.',
      });
    }
    return _moveToNextCard();
  }

  LiveAgentToolResult _moveToNextCard() {
    _index += 1;
    _currentCardAssessed = false;
    _assessmentRating = null;
    _heard = '';
    _feedback = '';

    if (_index >= _prompts.length) {
      _completed = true;
      notifyListeners();
      return LiveAgentToolResult({
        'ok': true,
        'completed': true,
        'reviewed_count': _reviewedCount,
        'instruction': 'Briefly congratulate the learner and end the session.',
      });
    }

    notifyListeners();
    return LiveAgentToolResult({
      'ok': true,
      'completed': false,
      'card': _contextMap(currentPrompt!),
      'instruction':
          'Ask the new card question now without revealing the answer.',
    });
  }

  Future<void> repeat() => _session.sendInstruction(
    'Repeat the current card question without revealing the answer.',
    requestResponse: true,
  );

  Future<void> skip() async {
    if (_completed || currentPrompt == null) return;
    final result = _moveToNextCard();
    await _session.sendInstruction(
      jsonEncode(result.output),
      requestResponse: true,
    );
  }

  Future<void> togglePaused() async {
    final paused = phase != VoiceStudyPhase.paused;
    await _session.setPaused(paused);
    if (!paused && currentPrompt != null) {
      await _session.sendInstruction(
        _contextForCurrentCard(firstCard: false),
        requestResponse: true,
      );
    }
  }

  Future<void> toggleMuted() => _session.toggleMuted();

  Future<void> stop() => _session.stop();

  Future<void> end() async {
    if (_completed) return;
    _completed = true;
    notifyListeners();
    await _session.stop();
  }

  Map<String, Object?> _answerPayload(StudyPrompt prompt) {
    final pronunciationHint = _pronunciationHint(prompt);
    return {
      'question': prompt.prompt,
      'answer': _expectedAnswer(prompt),
      if (pronunciationHint.isNotEmpty) 'pronunciation_hint': pronunciationHint,
    };
  }

  Map<String, Object?> _contextMap(StudyPrompt prompt) {
    final languages = _deckLanguages[prompt.card.deckId];
    return {
      'card_id': prompt.card.id,
      'deck': prompt.card.deckName,
      'from_language': languages?.from,
      'to_language': languages?.to,
      'question': prompt.prompt,
      'expected_answer': _expectedAnswer(prompt),
      if (_pronunciationHint(prompt).isNotEmpty)
        'pronunciation_hint': _pronunciationHint(prompt),
      'cue': prompt.cue.storageKey,
      'question_instruction': _questionInstruction(prompt, languages),
      'already_assessed': _currentCardAssessed,
    };
  }

  String _expectedAnswer(StudyPrompt prompt) => switch (prompt.cue) {
    StudyCue.fromLanguage => prompt.card.back,
    StudyCue.toLanguage || StudyCue.transliteration => prompt.card.front,
  };

  String _pronunciationHint(StudyPrompt prompt) => switch (prompt.cue) {
    StudyCue.fromLanguage => _languageContent(prompt)?.transliteration ?? '',
    StudyCue.toLanguage || StudyCue.transliteration => '',
  };

  String _questionInstruction(
    StudyPrompt prompt,
    VoiceStudyDeckLanguages? languages,
  ) {
    final from = languages?.from;
    final to = languages?.to;
    return switch (prompt.cue) {
      StudyCue.fromLanguage when to != null =>
        'Ask: How do you say ${prompt.prompt} in $to?',
      StudyCue.toLanguage || StudyCue.transliteration when from != null =>
        'Ask: What does ${prompt.prompt} mean in $from?',
      _ => 'Ask the learner to recall the answer to ${prompt.prompt}.',
    };
  }

  String _contextForCurrentCard({required bool firstCard}) {
    final prompt = currentPrompt!;
    return jsonEncode({
      'event': firstCard ? 'session_started' : 'card_resumed',
      'card': _contextMap(prompt),
      'instruction': 'Ask the card question now without revealing the answer.',
    });
  }

  LanguageCardContent? _languageContent(StudyPrompt prompt) {
    final content = prompt.card.content;
    return content is LanguageCardContent ? content : null;
  }

  void _replaceCard(int id, StudyCard updated) {
    for (var i = 0; i < _prompts.length; i += 1) {
      if (_prompts[i].card.id == id) {
        _prompts[i] = _prompts[i].withCard(updated);
      }
    }
  }

  void _syncSession() {
    notifyListeners();
  }

  @override
  void dispose() {
    _session.removeListener(_syncSession);
    _session.dispose();
    super.dispose();
  }
}

const _perMillion = 1000000;
const _textInputPrice = 4.0;
const _audioInputPrice = 32.0;
const _cachedInputPrice = 0.4;
const _textOutputPrice = 16.0;
const _audioOutputPrice = 64.0;

double _gptRealtimeInputCost(LiveAgentUsage usage) {
  var cachedText = math.min(usage.inputTextTokens, usage.cachedInputTextTokens);
  var cachedAudio = math.min(
    usage.inputAudioTokens,
    usage.cachedInputAudioTokens,
  );
  var remainingCached = math.max(
    0,
    usage.cachedInputTokens - cachedText - cachedAudio,
  );
  final additionalCachedText = math.min(
    usage.inputTextTokens - cachedText,
    remainingCached,
  );
  cachedText += additionalCachedText;
  remainingCached -= additionalCachedText;
  final additionalCachedAudio = math.min(
    usage.inputAudioTokens - cachedAudio,
    remainingCached,
  );
  cachedAudio += additionalCachedAudio;
  remainingCached -= additionalCachedAudio;
  final categorizedInput = usage.inputTextTokens + usage.inputAudioTokens;
  final otherInput = math.max(
    0,
    usage.inputTokens - categorizedInput - remainingCached,
  );
  return ((usage.inputTextTokens - cachedText + otherInput) * _textInputPrice +
          (usage.inputAudioTokens - cachedAudio) * _audioInputPrice +
          (cachedText + cachedAudio + remainingCached) * _cachedInputPrice) /
      _perMillion;
}

double _gptRealtimeOutputCost(LiveAgentUsage usage) {
  final categorizedOutput = usage.outputTextTokens + usage.outputAudioTokens;
  final otherOutput = math.max(0, usage.outputTokens - categorizedOutput);
  return ((usage.outputTextTokens + otherOutput) * _textOutputPrice +
          usage.outputAudioTokens * _audioOutputPrice) /
      _perMillion;
}

CardRating cardRatingForTutorResult(String? result) {
  return switch (result?.trim().toLowerCase()) {
    'good' || 'correct' => CardRating.good,
    'hard' || 'partial' => CardRating.hard,
    'easy' => CardRating.easy,
    _ => CardRating.again,
  };
}
