import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewProgressionSettings {
  const ReviewProgressionSettings({
    this.automaticProgressionEnabled = true,
    this.historyWindow = 5,
    this.moveToPastPercentage = 100,
    this.moveToCurrentPercentage = 60,
    this.autoReplacePromotedCards = true,
  });

  final bool automaticProgressionEnabled;
  final int historyWindow;
  final int moveToPastPercentage;
  final int moveToCurrentPercentage;
  final bool autoReplacePromotedCards;

  bool get isValid =>
      historyWindow > 0 &&
      moveToCurrentPercentage >= 0 &&
      moveToPastPercentage <= 100 &&
      moveToCurrentPercentage < moveToPastPercentage;

  Map<String, Object> toJson() => <String, Object>{
    'automatic_progression_enabled': automaticProgressionEnabled,
    'history_window': historyWindow,
    'move_to_past_percentage': moveToPastPercentage,
    'move_to_current_percentage': moveToCurrentPercentage,
    'auto_replace_promoted_cards': autoReplacePromotedCards,
  };

  factory ReviewProgressionSettings.fromJson(Map<String, Object?> json) {
    final settings = ReviewProgressionSettings(
      automaticProgressionEnabled:
          json['automatic_progression_enabled'] as bool? ?? true,
      historyWindow: (json['history_window'] as num?)?.round() ?? 5,
      moveToPastPercentage:
          (json['move_to_past_percentage'] as num?)?.round() ?? 100,
      moveToCurrentPercentage:
          (json['move_to_current_percentage'] as num?)?.round() ?? 60,
      autoReplacePromotedCards:
          json['auto_replace_promoted_cards'] as bool? ?? true,
    );
    return settings.isValid ? settings : const ReviewProgressionSettings();
  }
}

class ReviewProgressionSettingsStore {
  static const _key = 'nx_cards.review_progression_settings.v1';

  Future<ReviewProgressionSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) return const ReviewProgressionSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ReviewProgressionSettings.fromJson(decoded);
      }
    } on FormatException {
      // Fall through to safe defaults when old/local data is malformed.
    }
    return const ReviewProgressionSettings();
  }

  Future<void> save(ReviewProgressionSettings settings) async {
    if (!settings.isValid) {
      throw ArgumentError('Review progression thresholds must not overlap.');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, jsonEncode(settings.toJson()));
  }
}

final reviewProgressionSettingsStoreProvider =
    Provider<ReviewProgressionSettingsStore>(
      (ref) => ReviewProgressionSettingsStore(),
    );

final reviewProgressionSettingsProvider =
    FutureProvider<ReviewProgressionSettings>(
      (ref) => ref.watch(reviewProgressionSettingsStoreProvider).load(),
    );
