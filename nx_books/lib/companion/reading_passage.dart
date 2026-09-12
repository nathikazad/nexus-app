import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Passage delivery is route-scoped even when the renderer is retained.
final readerPassageProvider = Provider.autoDispose
    .family<ValueNotifier<String>, LocalKey>((ref, key) {
      final passage = ValueNotifier<String>('');
      ref.onDispose(passage.dispose);
      return passage;
    });
