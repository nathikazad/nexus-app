sealed class CardContent {
  const CardContent({required this.front, required this.back});

  final String front;
  final String back;
}

enum LearningStatus {
  notStarted('not_started'),
  learning('learning'),
  learnt('learnt');

  const LearningStatus(this.storageValue);

  final String storageValue;

  bool get isRecallEligible => this != LearningStatus.notStarted;

  static LearningStatus fromStorage(Object? value) => switch (value) {
    'learning' => LearningStatus.learning,
    'learnt' => LearningStatus.learnt,
    _ => LearningStatus.notStarted,
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
    this.examples = const <LanguageExample>[],
  }) : super(front: english, back: originalScript);

  String get english => front;
  String get originalScript => back;

  final String transliteration;
  final String? audioUrl;
  final List<LanguageExample> examples;
}

final class LanguageExample {
  const LanguageExample({
    required this.text,
    required this.transliteration,
    required this.translation,
    this.audioUrl,
  });

  final String text;
  final String transliteration;
  final String translation;
  final String? audioUrl;

  Map<String, Object?> toJson() => <String, Object?>{
    'text': text,
    'transliteration': transliteration,
    'translation': translation,
    if (audioUrl?.isNotEmpty == true) 'audio_url': audioUrl,
  };

  factory LanguageExample.fromJson(Map<String, dynamic> json) =>
      LanguageExample(
        text: json['text']?.toString().trim() ?? '',
        transliteration: json['transliteration']?.toString().trim() ?? '',
        translation: json['translation']?.toString().trim() ?? '',
        audioUrl: json['audio_url']?.toString().trim(),
      );
}
