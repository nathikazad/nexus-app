import 'package:flutter/material.dart';

/// Card-level mode, independent of the current listening question.
class CardStudyInfo extends StatelessWidget {
  const CardStudyInfo({
    super.key,
    required this.spokenOnly,
    required this.onOpen,
    this.onSlowPlayback,
  });
  final bool spokenOnly;
  final VoidCallback onOpen;
  final ValueChanged<double>? onSlowPlayback;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (spokenOnly && onSlowPlayback != null)
        for (final rate in [0.25, 0.5])
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            onPressed: () => onSlowPlayback!(rate),
            child: Text('$rate×'),
          ),
      if (spokenOnly)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Audio only',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      IconButton(
        tooltip: 'Card details',
        onPressed: onOpen,
        icon: const Icon(Icons.info_outline_rounded, size: 22),
      ),
    ],
  );
}
