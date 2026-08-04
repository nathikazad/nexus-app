sealed class CardContent {
  const CardContent({required this.front, required this.back});

  final String front;
  final String back;
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
  }) : super(front: english, back: originalScript);

  String get english => front;
  String get originalScript => back;

  final String transliteration;
  final String? audioUrl;
}
