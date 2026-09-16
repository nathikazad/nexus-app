import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nx_cards/browser/browser.dart';

/// Only session actions cross this bridge; the Android activity owns its UI.
class NativeDrawingSession {
  static const channel = MethodChannel('nx_cards/drawing-session');

  static Map<String, Object?> practiceCard(StudyCard card) {
    final content = card.content as LanguageCardContent;
    return {
      'prompt': content.originalScript,
      'answer': content.originalScript,
      'subtitle': '${content.transliteration} · ${content.english}',
      'audio': content.audioUrl?.isNotEmpty == true,
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
