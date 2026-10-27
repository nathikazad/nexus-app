import 'package:flutter/material.dart';
import 'package:nx_cards/browser/browser.dart';

class RecallDirectionChoices extends StatelessWidget {
  const RecallDirectionChoices({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final Set<StudyCue> selected;
  final ValueChanged<Set<StudyCue>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final source in RecallComponent.values) ...[
          if (source != RecallComponent.values.first) const SizedBox(width: 6),
          Expanded(child: _button(context, source)),
        ],
      ],
    );
  }

  Widget _button(BuildContext context, RecallComponent source) {
    final active = selected.any((cue) => cue.source == source);
    final states = active ? {WidgetState.selected} : <WidgetState>{};
    final selectionStyle = Theme.of(context).segmentedButtonTheme.style;
    return OutlinedButton(
      key: ValueKey('recall-source-${source.name}'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        backgroundColor:
            selectionStyle?.backgroundColor?.resolve(states) ??
            (active ? Theme.of(context).colorScheme.primary : null),
        foregroundColor:
            selectionStyle?.foregroundColor?.resolve(states) ??
            (active ? Theme.of(context).colorScheme.onPrimary : null),
        textStyle: TextStyle(
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
        ),
        side: BorderSide(
          color: active
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
          width: active ? 2 : 1,
        ),
      ),
      onPressed: () {
        final next = {...selected};
        if (active) {
          next.removeWhere((cue) => cue.source == source);
        } else {
          next.addAll(
            StudyCue.languageDirections.where((cue) => cue.source == source),
          );
        }
        onChanged(next);
      },
      child: Semantics(
        selected: active,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(source.label, maxLines: 1),
        ),
      ),
    );
  }
}
