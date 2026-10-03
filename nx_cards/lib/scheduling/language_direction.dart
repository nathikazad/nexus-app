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
    String label(StudyCue value) => value.label;
    Widget compactLabel(StudyCue value) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value == StudyCue.fromAudio) ...[
          const Icon(Icons.volume_up_outlined, size: 18),
          const SizedBox(width: 6),
        ],
        Text(value.label),
      ],
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
    this.allowed = StudyCue.activeDirections,
    this.frontOnly = false,
  });
  final String language;
  final List<StudyCue> allowed;
  final bool frontOnly;
  final Set<StudyCue> selected;
  final ValueChanged<Set<StudyCue>> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final cue in allowed)
        FilterChip(
          key: ValueKey('direction-${cue.storageKey}'),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cue == StudyCue.fromAudio) ...[
                const Icon(Icons.volume_up_outlined, size: 18),
                const SizedBox(width: 6),
              ],
              Text(cue.label),
            ],
          ),
          tooltip: switch (cue) {
            StudyCue.fromLanguage => 'Show English meaning',
            StudyCue.fromAudio => 'Play $language sound',
            _ => 'Show $language script',
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
