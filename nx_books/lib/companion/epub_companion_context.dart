import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EpubCompanionContext {
  const EpubCompanionContext(this.bookId, this.text);
  final int bookId;
  final String text;
}

/// Null outside EPUB; empty text while loading. Owned by the host.
final epubCompanionContextProvider =
    Provider<ValueNotifier<EpubCompanionContext?>>((ref) {
      final context = ValueNotifier<EpubCompanionContext?>(null);
      ref.onDispose(context.dispose);
      return context;
    });

bool isReadingSummaryPath(Uri uri) {
  final parts = uri.pathSegments;
  return parts.length == 3 &&
      (parts[0] == 'books' || parts[0] == 'documents') &&
      int.tryParse(parts[1]) != null &&
      parts[2] == 'notes';
}
