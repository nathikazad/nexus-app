import 'package:flutter/material.dart';

Future<bool> confirmEndRecall(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End recall?'),
        content: const Text('Your completed answers will be kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep recalling'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End recall'),
          ),
        ],
      ),
    ) ??
    false;
