import 'package:nx_notes/domain/document/document_query.dart';

enum CatalogKind { all, recent, pinned, books, search, tag }

final class CatalogQuery {
  const CatalogQuery._({
    required this.kind,
    this.limit,
    this.searchText = '',
    this.tagFilter,
  });

  const CatalogQuery.all() : this._(kind: CatalogKind.all);

  const CatalogQuery.recent({int limit = 20})
    : this._(kind: CatalogKind.recent, limit: limit);

  const CatalogQuery.pinned({int limit = 20})
    : this._(kind: CatalogKind.pinned, limit: limit);

  const CatalogQuery.books({int limit = 100})
    : this._(kind: CatalogKind.books, limit: limit);

  const CatalogQuery.search(String text)
    : this._(kind: CatalogKind.search, searchText: text);

  const CatalogQuery.tag(DocumentTagFilter filter)
    : this._(kind: CatalogKind.tag, tagFilter: filter);

  final CatalogKind kind;
  final int? limit;
  final String searchText;
  final DocumentTagFilter? tagFilter;

  String get cacheKey => switch (kind) {
    CatalogKind.all => 'all',
    CatalogKind.recent => 'recent:${limit ?? 20}',
    CatalogKind.pinned => 'pinned:${limit ?? 20}',
    CatalogKind.books => 'books:${limit ?? 100}',
    CatalogKind.search => 'search:${searchText.trim().toLowerCase()}',
    CatalogKind.tag =>
      'tag:${tagFilter!.system}:${tagFilter!.node}:'
          '${tagFilter!.includeDescendants}',
  };

  bool get persistsMembership => switch (kind) {
    CatalogKind.all ||
    CatalogKind.recent ||
    CatalogKind.pinned ||
    CatalogKind.books => true,
    CatalogKind.search || CatalogKind.tag => false,
  };

  @override
  bool operator ==(Object other) {
    return other is CatalogQuery && other.cacheKey == cacheKey;
  }

  @override
  int get hashCode => cacheKey.hashCode;
}
