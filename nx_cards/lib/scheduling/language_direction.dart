import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_cards/browser/browser.dart';

// Watching the authenticated account disposes direction choices on account change.
final languageDirectionProvider = StateProvider.family<StudyCue, String?>((
  ref,
  language,
) {
  if (ref.exists(authProvider)) {
    ref.watch(
      authProvider.select(
        (state) => '${state.value?.preset.serverId}:${state.value?.userId}',
      ),
    );
  }
  return StudyCue.fromLanguage;
});

/// Compact display only; direction identity still uses the full language name.
String compactLanguageLabel(String language) =>
    switch (language.trim().toLowerCase()) {
      'english' => 'EN',
      'chinese' || 'mandarin' => '中',
      'tamil' => 'தமிழ்',
      'malayalam' => 'മലയാളം',
      _ => language,
    };

class LanguageDirectionButton extends ConsumerWidget {
  const LanguageDirectionButton({super.key, required this.language});
  final String language;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cue = ref.watch(languageDirectionProvider(language));
    String label(StudyCue value) => value == StudyCue.fromLanguage
        ? 'English → $language'
        : '$language → English';
    return PopupMenuButton<StudyCue>(
      tooltip: 'Recall direction: ${label(cue)}',
      initialValue: cue,
      onSelected: (value) =>
          ref.read(languageDirectionProvider(language).notifier).state = value,
      itemBuilder: (_) => [
        for (final value in StudyCue.activeDirections)
          PopupMenuItem(value: value, child: Text(label(value))),
      ],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          cue == StudyCue.fromLanguage
              ? 'EN → ${compactLanguageLabel(language)}'
              : '${compactLanguageLabel(language)} → EN',
        ),
      ),
    );
  }
}
