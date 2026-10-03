import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_cards/browser/browser.dart';

// Watching the authenticated account disposes direction choices on account change.
final languageDirectionProvider =
    StateProvider.family<RecallComponent, String?>((ref, language) {
      if (ref.exists(authProvider)) {
        ref.watch(
          authProvider.select(
            (state) => '${state.value?.preset.serverId}:${state.value?.userId}',
          ),
        );
      }
      return RecallComponent.meaning;
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
    String label(RecallComponent value) => value.label;
    Widget compactLabel(RecallComponent value) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value == RecallComponent.sound) ...[
          const Icon(Icons.volume_up_outlined, size: 18),
          const SizedBox(width: 6),
        ],
        Text(value.label),
      ],
    );
    return PopupMenuButton<RecallComponent>(
      tooltip: 'Recall direction: ${label(cue)}',
      initialValue: cue,
      onSelected: (value) =>
          ref.read(languageDirectionProvider(language).notifier).state = value,
      itemBuilder: (_) => [
        for (final value in RecallComponent.values)
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
final selectedDirectionsProvider =
    StateProvider.family<Set<RecallComponent>, String?>((ref, language) {
      if (ref.exists(authProvider)) {
        ref.watch(
          authProvider.select(
            (state) => '${state.value?.preset.serverId}:${state.value?.userId}',
          ),
        );
      }
      return RecallComponent.values.toSet();
    });

class DirectionChoices extends StatelessWidget {
  const DirectionChoices({
    super.key,
    required this.language,
    required this.selected,
    required this.onChanged,
    this.allowed = RecallComponent.values,
    this.frontOnly = false,
    this.retentionPercentages = const {},
  });
  final String language;
  final List<RecallComponent> allowed;
  final bool frontOnly;
  final Map<RecallComponent, int> retentionPercentages;
  final Set<RecallComponent> selected;
  final ValueChanged<Set<RecallComponent>> onChanged;

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
              if (cue == RecallComponent.sound) ...[
                const Icon(Icons.volume_up_outlined, size: 18),
                const SizedBox(width: 6),
              ],
              Text(cue.label),
              if (retentionPercentages[cue] case final percentage?) ...[
                const SizedBox(width: 6),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          tooltip: switch (cue) {
            RecallComponent.meaning => 'Practice involving meaning',
            RecallComponent.sound => 'Practice involving sound',
            _ => 'Practice involving script',
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
