import 'package:flutter/material.dart';

/// Card-level mode, independent of the current listening question.
class CardStudyInfo extends StatelessWidget {
  const CardStudyInfo({
    super.key,
    required this.spokenOnly,
    required this.onOpen,
    this.visible = true,
  });
  final bool spokenOnly;
  final bool visible;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Visibility(
    visible: visible,
    maintainSize: true,
    maintainAnimation: true,
    maintainState: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
    ),
  );
}
