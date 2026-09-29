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
    String label(StudyCue value) => switch (value) {
      StudyCue.fromLanguage => 'English → $language',
      StudyCue.fromAudio => '$language audio → $language',
      _ => '$language text → English',
    };
    Widget compactLabel(StudyCue value) => Semantics(
      label: label(value),
      excludeSemantics: true,
      child: value == StudyCue.fromAudio
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.volume_up_outlined, size: 20),
                Text(' → ${compactLanguageLabel(language)}'),
              ],
            )
          : Text(
              value == StudyCue.fromLanguage
                  ? 'EN → ${compactLanguageLabel(language)}'
                  : '${compactLanguageLabel(language)} → EN',
            ),
    );
    return PopupMenuButton<StudyCue>(
      tooltip: 'Recall direction: ${label(cue)}',
      initialValue: cue,
      onSelected: (value) =>
          ref.read(languageDirectionProvider(language).notifier).state = value,
      itemBuilder: (_) => [
        for (final value in StudyCue.activeDirections)
          PopupMenuItem(
            key: ValueKey('recall-direction-${value.storageKey}'),
            value: value,
            child: compactLabel(value),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: compactLabel(cue),
      ),
    );
  }
}

/// Session-only view selection; never changes stored schedules or history.
final selectedDirectionsProvider = StateProvider.family<Set<StudyCue>, String?>(
  (ref, language) {
    if (ref.exists(authProvider)) {
      ref.watch(
        authProvider.select(
          (state) => '${state.value?.preset.serverId}:${state.value?.userId}',
        ),
      );
    }
    return StudyCue.activeDirections.toSet();
  },
);

class DirectionChoices extends StatelessWidget {
  const DirectionChoices({
    super.key,
    required this.language,
    required this.selected,
    required this.onChanged,
  });
  final String language;
  final Set<StudyCue> selected;
  final ValueChanged<Set<StudyCue>> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final cue in StudyCue.activeDirections)
        FilterChip(
          key: ValueKey('direction-${cue.storageKey}'),
          avatar: cue == StudyCue.fromAudio
              ? const Icon(Icons.volume_up_outlined, size: 18)
              : null,
          label: Text(switch (cue) {
            StudyCue.fromLanguage => 'EN → ${compactLanguageLabel(language)}',
            StudyCue.fromAudio => '→ ${compactLanguageLabel(language)}',
            _ => '${compactLanguageLabel(language)} → EN',
          }),
          tooltip: switch (cue) {
            StudyCue.fromLanguage => 'English text to $language',
            StudyCue.fromAudio => '$language audio to $language',
            _ => '$language text to English',
          },
          selected: selected.contains(cue),
          onSelected: (enabled) {
            final next = {...selected};
            if (enabled) {
              next.add(cue);
            } else {
              next.remove(cue);
            }
            if (next.isNotEmpty) onChanged(next);
          },
        ),
    ],
  );
}
