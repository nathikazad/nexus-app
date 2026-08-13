/// A node in a hierarchical or flat tag system (from `get_kgql_model_type` → `tag_systems` → `nodes`).
class TagNode {
  final int id;
  final String name;
  final int? sortOrder;
  final List<TagNode>? children;

  const TagNode({
    required this.id,
    required this.name,
    this.sortOrder,
    this.children,
  });

  factory TagNode.fromJson(Map<String, dynamic> json) {
    List<TagNode>? children;
    final raw = json['children'];
    if (raw is List && raw.isNotEmpty) {
      children = raw
          .map((e) => TagNode.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return TagNode(
      id: json['id'] as int,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int? ?? json['sortOrder'] as int?,
      children: children,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (children != null && children!.isNotEmpty)
        'children': children!.map((c) => c.toJson()).toList(),
    };
  }

  /// Leaf display names (depth-first); includes this node if it has no children.
  List<String> get leafNames {
    if (children == null || children!.isEmpty) {
      return [name];
    }
    return children!.expand((c) => c.leafNames).toList();
  }
}
