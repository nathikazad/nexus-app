import 'package:nx_docs/documents/document_models.dart';

final class CatalogState {
  const CatalogState({
    this.items = const <DocumentSummary>[],
    this.isInitialLoading = true,
    this.isRefreshing = false,
    this.error,
  });

  final List<DocumentSummary> items;
  final bool isInitialLoading;
  final bool isRefreshing;
  final Object? error;

  bool get hasData => items.isNotEmpty;

  CatalogState copyWith({
    List<DocumentSummary>? items,
    bool? isInitialLoading,
    bool? isRefreshing,
    Object? error,
    bool clearError = false,
  }) {
    return CatalogState(
      items: items ?? this.items,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : error ?? this.error,
    );
  }
}
