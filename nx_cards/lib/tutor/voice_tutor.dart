import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:nx_live_agent/nx_live_agent.dart';

import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/card_scheduler.dart';

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

typedef VoiceStudyLanguages = ({String? from, String? to});

final class VoiceStudyAnswerReveal {
  const VoiceStudyAnswerReveal({
    required this.english,
    required this.malayalam,
    required this.transliteration,
    required this.rating,
    required this.feedback,
  });

  final String english;
  final String malayalam;
  final String transliteration;
  final CardRating rating;
  final String feedback;
}

final class VoiceStudyRecapEntry {
  const VoiceStudyRecapEntry({
    required this.english,
    required this.malayalam,
    required this.transliteration,
    required this.rating,
    required this.tokens,
  });

  final String english;
  final String malayalam;
  final String transliteration;
  final CardRating? rating;
  final int tokens;
}

class VoiceTutorController extends ChangeNotifier {
  factory VoiceTutorController({
    required LiveAgentSession session,
    required CardLibrary repository,
    required CardScheduler scheduler,
    required List<StudyPrompt> prompts,
    VoiceStudyLanguages? languages,
    required VoidCallback onScheduleSaved,
    DateTime Function()? now,
  }) => VoiceTutorController._(
    session,
    repository,
    scheduler,
    prompts,
    languages,
    onScheduleSaved,
    now ?? DateTime.now,
  );

  VoiceTutorController._(
    this._session,
    this._repository,
    this._scheduler,
    List<StudyPrompt> prompts,
    this._languages,
    this._onScheduleSaved,
    this._now,
  ) : _prompts = List<StudyPrompt>.of(prompts) {
    _session.addListener(_syncSession);
  }

  final LiveAgentSession _session;
  final CardLibrary _repository;
  final CardScheduler _scheduler;
  final List<StudyPrompt> _prompts;
  final VoiceStudyLanguages? _languages;
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
  VoiceStudyAnswerReveal? _answerReveal;
  final Map<int, CardRating> _ratingsByPromptIndex = <int, CardRating>{};
  final Map<int, int> _tokensByPromptIndex = <int, int>{};
  int _usagePromptIndex = 0;
  int _lastObservedTokens = 0;
  int _lastPlaybackCompletionCount = 0;
  bool _clearRevealAfterPlayback = false;

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
  VoiceStudyAnswerReveal? get answerReveal => _answerReveal;
  List<VoiceStudyRecapEntry> get recapEntries => <VoiceStudyRecapEntry>[
    for (var promptIndex = 0; promptIndex < _prompts.length; promptIndex += 1)
      if (_ratingsByPromptIndex.containsKey(promptIndex) ||
          (_tokensByPromptIndex[promptIndex] ?? 0) > 0)
        _recapEntry(promptIndex),
  ];
  List<StudyCard> get reviewedCards {
    final cards = <int, StudyCard>{};
    for (final entry in _ratingsByPromptIndex.entries) {
      cards[_prompts[entry.key].card.id] = _prompts[entry.key].card;
    }
    return List<StudyCard>.unmodifiable(cards.values);
  }

  String? get error => _session.error;
  StudyPrompt? get currentPrompt =>
      _index < _prompts.length ? _prompts[_index] : null;
  StudyPrompt? get displayedPrompt =>
      _clearRevealAfterPlayback ? null : currentPrompt;
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
        model: 'gpt-realtime-2.1-mini',
      ),
      tools: _tools,
    );
  }

  List<LiveAgentTool> get _tools => [
    CallbackLiveAgentTool(
      definition: const LiveAgentToolDefinition(
        name: 'assess_current_card',
        description:
            'Save the learner assessment for the current card. A good rating '
            'automatically advances to the next card; again and hard remain '
            'on the current card.',
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
The current card context supplies its source and language.

For every card:
1. Ask the supplied question without revealing the answer first. Follow the
   supplied question_instruction, which accounts for the selected cue and the
   selected source and target languages.
2. Listen to the learner. If they answer, say they do not know, or give up, call
   assess_current_card exactly once. Use again for unknown/wrong, hard for a
   partially correct or hesitant answer, and good for a confident correct one.
3. After assessment, teach or confirm the authoritative answer returned by the
   tool. Do not invent a spelling or transliteration. If the answer was good,
   the tool advances automatically: briefly confirm it and immediately ask the
   supplied next card question. Do not call advance_card for a good answer.
   Say the answer only once. Treat pronunciation_hint and stored example
   transliterations as silent pronunciation aids. Never read a target-language word
   and then repeat its transliteration unless the learner explicitly asks for
   the transliteration.
4. After an again or hard assessment, stay anchored to the same card for
   follow-up questions. If asked for examples or usage, call
   get_current_examples and use only those stored examples.
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
    _answerReveal = _answerRevealFor(prompt, rating, _feedback);
    _ratingsByPromptIndex[_index] = rating;
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

    if (rating == CardRating.good || rating == CardRating.easy) {
      final answer = _answerPayload(prompt);
      final advance = _moveToNextCard();
      final advanceOutput = Map<String, Object?>.from(advance.output! as Map);
      final completed = advanceOutput['completed'] == true;
      return LiveAgentToolResult({
        'ok': true,
        'saved': true,
        'rating': rating.name,
        'feedback': _answerReveal!.feedback,
        ...answer,
        'advanced': true,
        ...advanceOutput,
        'instruction': completed
            ? 'Briefly confirm the correct answer, congratulate the learner, '
                  'and give one short closing sentence.'
            : 'Briefly confirm the correct answer once, then immediately ask '
                  'the supplied new card question without revealing its answer.',
      }, discardConversationBeforeResponse: true);
    }

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
      _session.closeAfterNextPlayback();
      notifyListeners();
      return LiveAgentToolResult({
        'ok': true,
        'completed': true,
        'reviewed_count': _reviewedCount,
        'instruction': 'Briefly congratulate the learner and end the session.',
      }, discardConversationBeforeResponse: true);
    }

    _clearRevealAfterPlayback = _answerReveal != null;
    _usagePromptIndex = _index;
    notifyListeners();
    return LiveAgentToolResult({
      'ok': true,
      'completed': false,
      'card': _contextMap(currentPrompt!),
      'instruction':
          'Ask the new card question now without revealing the answer.',
    }, discardConversationBeforeResponse: true);
  }

  Future<void> repeat() => _session.sendInstruction(
    'Repeat the current card question without revealing the answer.',
    requestResponse: true,
  );

  Future<void> skip() async {
    if (_completed || currentPrompt == null) return;
    final result = _moveToNextCard();
    await _session.discardConversation();
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

  Future<void> toggleMuted() => _session.activateMicrophone();

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
    final languages = _languages;
    return {
      'card_id': prompt.card.id,
      'source': prompt.card.sourceBookName ?? prompt.card.language,
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
    VoiceStudyLanguages? languages,
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

  VoiceStudyAnswerReveal _answerRevealFor(
    StudyPrompt prompt,
    CardRating rating,
    String feedback,
  ) {
    final content = _languageContent(prompt);
    return VoiceStudyAnswerReveal(
      english: content?.english ?? prompt.card.front,
      malayalam: content?.originalScript ?? prompt.card.back,
      transliteration: content?.transliteration ?? '',
      rating: rating,
      feedback: feedback,
    );
  }

  VoiceStudyRecapEntry _recapEntry(int promptIndex) {
    final prompt = _prompts[promptIndex];
    final content = _languageContent(prompt);
    return VoiceStudyRecapEntry(
      english: content?.english ?? prompt.card.front,
      malayalam: content?.originalScript ?? prompt.card.back,
      transliteration: content?.transliteration ?? '',
      rating: _ratingsByPromptIndex[promptIndex],
      tokens: _tokensByPromptIndex[promptIndex] ?? 0,
    );
  }

  void _replaceCard(int id, StudyCard updated) {
    for (var i = 0; i < _prompts.length; i += 1) {
      if (_prompts[i].card.id == id) {
        _prompts[i] = _prompts[i].withCard(updated);
      }
    }
  }

  void _syncSession() {
    final totalTokens = _session.usage.totalTokens;
    final newTokens = math.max(0, totalTokens - _lastObservedTokens);
    if (newTokens > 0 && _prompts.isNotEmpty) {
      _tokensByPromptIndex.update(
        _usagePromptIndex,
        (tokens) => tokens + newTokens,
        ifAbsent: () => newTokens,
      );
    }
    _lastObservedTokens = totalTokens;
    if (_session.playbackCompletionCount > _lastPlaybackCompletionCount) {
      _lastPlaybackCompletionCount = _session.playbackCompletionCount;
      if (_clearRevealAfterPlayback) {
        _clearRevealAfterPlayback = false;
        _answerReveal = null;
      }
    }
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
const _textInputPrice = 0.6;
const _audioInputPrice = 10.0;
const _cachedTextInputPrice = 0.06;
const _cachedAudioInputPrice = 0.3;
const _textOutputPrice = 2.4;
const _audioOutputPrice = 20.0;
const _transcriptionInputPrice = 1.25;
const _transcriptionOutputPrice = 5.0;

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
          (cachedText + remainingCached) * _cachedTextInputPrice +
          cachedAudio * _cachedAudioInputPrice +
          usage.transcriptionInputTokens * _transcriptionInputPrice) /
      _perMillion;
}

double _gptRealtimeOutputCost(LiveAgentUsage usage) {
  final categorizedOutput = usage.outputTextTokens + usage.outputAudioTokens;
  final otherOutput = math.max(0, usage.outputTokens - categorizedOutput);
  return ((usage.outputTextTokens + otherOutput) * _textOutputPrice +
          usage.outputAudioTokens * _audioOutputPrice +
          usage.transcriptionOutputTokens * _transcriptionOutputPrice) /
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
