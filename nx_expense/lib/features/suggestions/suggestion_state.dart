import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_expense/data/suggestion/suggestion_api.dart';
import 'package:nx_expense/domain/suggestion/expense_suggestion.dart';

enum ExternalWorkspaceMode { review, transactions }

final externalWorkspaceModeProvider = StateProvider<ExternalWorkspaceMode>(
  (ref) => ExternalWorkspaceMode.review,
);

final selectedExpenseSuggestionIdProvider = StateProvider<int?>((ref) => null);

final openExpenseSuggestionsProvider = FutureProvider<List<ExpenseSuggestion>>((
  ref,
) async {
  final base = ref.watch(imageBaseUrlProvider);
  final userId = ref.watch(userIdProvider);
  if (base == null || base.trim().isEmpty) {
    throw StateError('Image / MCP HTTP URL is not configured.');
  }
  if (userId == null || userId.trim().isEmpty) {
    throw StateError('Not signed in.');
  }
  return fetchExpenseSuggestions(imageBaseUrl: base, userId: userId);
});
