sealed class CardContent {
  const CardContent({required this.front, required this.back});

  final String front;
  final String back;
}

enum LearningStatus {
  future('future', 'Backlog'),
  practice('practice', 'Upcoming'),
  recall('recall', 'Current');

  const LearningStatus(this.storageValue, this.label);
  final String storageValue;
  final String label;
  bool get isRecallEligible => this == LearningStatus.recall;

  static LearningStatus fromStorage(Object? value) => switch (value) {
    'recall' => LearningStatus.recall,
    'practice' => LearningStatus.practice,
    'future' || null => LearningStatus.future,
    _ => throw FormatException('Unknown learning state: $value'),
  };
}

final class BasicCardContent extends CardContent {
  const BasicCardContent({required super.front, required super.back});
}

final class LanguageCardContent extends CardContent {
  const LanguageCardContent({
    required String english,
    required String originalScript,
    required this.transliteration,
    this.audioUrl,
    this.audioSha256,
    this.audioBytes,
    this.similarWordGroups = const <String>[],
    List<LanguageExample> examples = const <LanguageExample>[],
    // Keep the public named argument compatible while filtering reads.
    // ignore: prefer_initializing_formals
  }) : _examples = examples,
       super(front: english, back: originalScript);

  String get english => front;
  String get originalScript => back;

  final List<String> similarWordGroups;
  final String transliteration;
  final String? audioUrl;
  final String? audioSha256;
  final int? audioBytes;
  final List<LanguageExample> _examples;

  LanguageCardContent copyWith({
    List<String>? similarWordGroups,
    String? english,
    String? originalScript,
    String? transliteration,
    String? audioUrl,
    String? audioSha256,
    int? audioBytes,
  }) => LanguageCardContent(
    english: english ?? this.english,
    originalScript: originalScript ?? this.originalScript,
    transliteration: transliteration ?? this.transliteration,
    audioUrl: audioUrl ?? this.audioUrl,
    audioSha256: audioSha256 ?? this.audioSha256,
    audioBytes: audioBytes ?? this.audioBytes,
    examples: _examples,
    similarWordGroups: similarWordGroups ?? this.similarWordGroups,
  );

  // A linked vocabulary item is not a usage example of itself. Keep the
  // underlying relation, but suppress identical text in every example view.
  List<LanguageExample> get examples => _examples
      .where((example) => example.text.trim() != originalScript.trim())
      .toList(growable: false);
}

final class LanguageExample {
  const LanguageExample({
    required this.text,
    required this.transliteration,
    required this.translation,
    this.audioUrl,
    this.audioSha256,
    this.audioBytes,
    this.cardId,
  });

  final int? cardId;
  final String text;
  final String transliteration;
  final String translation;
  final String? audioUrl;
  final String? audioSha256;
  final int? audioBytes;

  Map<String, Object?> toJson() => <String, Object?>{
    if (cardId != null) 'card_id': cardId,
    'text': text,
    'transliteration': transliteration,
    'translation': translation,
    if (audioUrl?.isNotEmpty == true) 'audio_url': audioUrl,
    if (audioSha256 != null) 'audio_sha256': audioSha256,
    if (audioBytes != null) 'audio_bytes': audioBytes,
  };

  factory LanguageExample.fromJson(Map<String, dynamic> json) =>
      LanguageExample(
        cardId: (json['card_id'] as num?)?.toInt(),
        text: json['text']?.toString().trim() ?? '',
        transliteration: json['transliteration']?.toString().trim() ?? '',
        translation: json['translation']?.toString().trim() ?? '',
        audioUrl: json['audio_url']?.toString().trim(),
        audioSha256: json['audio_sha256'] as String?,
        audioBytes: (json['audio_bytes'] as num?)?.toInt(),
      );
}
