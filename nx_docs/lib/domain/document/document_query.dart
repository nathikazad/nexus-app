class DocumentTagFilter {
  const DocumentTagFilter({
    required this.system,
    required this.node,
    this.includeDescendants = false,
  });

  final String system;
  final String node;
  final bool includeDescendants;
}

class DocumentQuery {
  const DocumentQuery({
    this.searchText = '',
    this.tagFilters = const <DocumentTagFilter>[],
    this.pinnedOnly = false,
  });

  final String searchText;
  final List<DocumentTagFilter> tagFilters;
  final bool pinnedOnly;
}
