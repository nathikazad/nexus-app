class TagNode {
  const TagNode({
    required this.name,
    this.count = 0,
    this.children = const <TagNode>[],
  });

  final String name;
  final int count;
  final List<TagNode> children;
}

class TagSystem {
  const TagSystem({
    required this.name,
    required this.nodes,
    this.hierarchical = false,
    this.exclusive = false,
  });

  final String name;
  final List<TagNode> nodes;
  final bool hierarchical;
  final bool exclusive;
}
