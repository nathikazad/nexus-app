class EssayTagFilter {
  const EssayTagFilter({
    required this.system,
    required this.node,
    this.includeDescendants = false,
  });

  final String system;
  final String node;
  final bool includeDescendants;
}

class EssayQuery {
  const EssayQuery({
    this.searchText = '',
    this.tagFilters = const <EssayTagFilter>[],
    this.pinnedOnly = false,
  });

  final String searchText;
  final List<EssayTagFilter> tagFilters;
  final bool pinnedOnly;
}
