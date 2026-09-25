sealed class CardContent {
  const CardContent({required this.front, required this.back});

  final String front;
  final String back;
}

enum LearningStatus {
  inactive('inactive', 'Inactive'),
  prep('prep', 'Prep'),
  active('active', 'Active');

  const LearningStatus(this.storageValue, this.label);
  final String storageValue;
  final String label;
  bool get isRecallEligible => this == LearningStatus.active;

  static LearningStatus fromStorage(
    Object? value, {
    bool hasRecallHistory = false,
  }) => switch (value) {
    'active' => LearningStatus.active,
    'prep' => LearningStatus.prep,
    'learning' ||
    'learnt' => hasRecallHistory ? LearningStatus.active : LearningStatus.prep,
    _ => LearningStatus.inactive,
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
    List<LanguageExample> examples = const <LanguageExample>[],
    // Keep the public named argument compatible while filtering reads.
    // ignore: prefer_initializing_formals
  }) : _examples = examples,
       super(front: english, back: originalScript);

  String get english => front;
  String get originalScript => back;

  final String transliteration;
  final String? audioUrl;
  final List<LanguageExample> _examples;

  LanguageCardContent copyWith({
    String? english,
    String? originalScript,
    String? transliteration,
    String? audioUrl,
  }) => LanguageCardContent(
    english: english ?? this.english,
    originalScript: originalScript ?? this.originalScript,
    transliteration: transliteration ?? this.transliteration,
    audioUrl: audioUrl ?? this.audioUrl,
    examples: _examples,
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
    this.cardId,
  });

  final int? cardId;
  final String text;
  final String transliteration;
  final String translation;
  final String? audioUrl;

  Map<String, Object?> toJson() => <String, Object?>{
    if (cardId != null) 'card_id': cardId,
    'text': text,
    'transliteration': transliteration,
    'translation': translation,
    if (audioUrl?.isNotEmpty == true) 'audio_url': audioUrl,
  };

  factory LanguageExample.fromJson(Map<String, dynamic> json) =>
      LanguageExample(
        cardId: (json['card_id'] as num?)?.toInt(),
        text: json['text']?.toString().trim() ?? '',
        transliteration: json['transliteration']?.toString().trim() ?? '',
        translation: json['translation']?.toString().trim() ?? '',
        audioUrl: json['audio_url']?.toString().trim(),
      );
}
