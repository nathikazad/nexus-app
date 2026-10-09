import 'package:flutter/material.dart';

Future<bool> confirmEndRecall(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End recall?'),
        content: const Text('Your completed answers will be kept.'),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep recalling'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('End recall'),
              ),
            ],
          ),
        ],
      ),
    ) ??
    false;
