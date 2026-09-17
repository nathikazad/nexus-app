import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:nx_cards/browser/browser.dart';

/// Only session actions cross this bridge; the Android activity owns its UI.
class NativeDrawingSession {
  static const channel = MethodChannel('nx_cards/drawing-session');

  /// Follow saved Contains links only, including phrase -> word -> character.
  static List<LanguageCardContent> characterParts(
    StudyCard card,
    Map<int, StudyCard> library,
  ) {
    final content = card.content as LanguageCardContent;
    final letters = content.originalScript.trim().characters.toList();
    if (letters.length <= 1) return const [];
    final visited = <int>{card.id};
    final parts = <LanguageCardContent>[];
    void visit(StudyCard parent) {
      for (final id in parent.linkedWordIds) {
        if (!visited.add(id)) continue;
        final child = library[id];
        if (child == null || child.content is! LanguageCardContent) continue;
        final part = child.content as LanguageCardContent;
        final text = part.originalScript.trim();
        if (text.characters.length == 1) {
          // Match whole written letters, not a consonant hidden inside a
          // combined letter. Stop here so வீ stays வீ, rather than வ் + ஈ.
          if (letters.contains(text)) parts.add(part);
          continue;
        }
        visit(child);
      }
    }

    visit(card);
    parts.sort(
      (a, b) => letters
          .indexOf(a.originalScript.trim())
          .compareTo(letters.indexOf(b.originalScript.trim())),
    );
    return parts;
  }

  static Map<String, Object?> practiceCard(
    StudyCard card, {
    List<LanguageCardContent> characters = const [],
  }) {
    final content = card.content as LanguageCardContent;
    return {
      'prompt': content.originalScript,
      'answer': content.originalScript,
      'subtitle': '${content.transliteration} · ${content.english}',
      'audio': content.audioUrl?.isNotEmpty == true,
      'multiCharacter': content.originalScript.trim().characters.length > 1,
      'characters': [
        for (final part in characters)
          {
            'text': part.originalScript,
            'transliteration': part.transliteration,
            'translation': part.english,
            'audio': part.audioUrl?.trim().isNotEmpty == true,
          },
      ],
      'examples': [
        for (final example in content.examples)
          {
            'text': example.text,
            'transliteration': example.transliteration,
            'translation': example.translation,
            'audio': example.audioUrl?.trim().isNotEmpty == true,
          },
      ],
    };
  }

  static Map<String, Object?> recallCard(StudyPrompt prompt) {
    final content = prompt.card.content as LanguageCardContent;
    return {
      'prompt': prompt.prompt,
      'answer': prompt.cue == StudyCue.fromLanguage
          ? content.originalScript
          : content.english,
      'subtitle':
          '${content.transliteration} · ${prompt.cue == StudyCue.fromLanguage ? content.english : content.originalScript}',
      'audio': content.audioUrl?.isNotEmpty == true,
    };
  }

  static Future<bool> isAvailable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await channel.invokeMethod<bool>('available') == true;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> open({
    required String title,
    required List<Map<String, Object?>> cards,
    required bool recall,
    required Future<Object?> Function(MethodCall) onAction,
  }) async {
    if (!await isAvailable()) return false;
    channel.setMethodCallHandler(onAction);
    try {
      await channel.invokeMethod<void>('open', {
        'title': title,
        'recall': recall,
        'cards': cards,
      });
      return true;
    } finally {
      channel.setMethodCallHandler(null);
    }
  }
}
