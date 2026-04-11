import 'TagNode.dart';

/// Tag system metadata attached to a model type (`get_kgql_model_type` → `tag_systems`).
class TagSystem {
  final int id;
  final String name;
  final bool isHierarchical;
  /// Backend: `exclusive` | `multiple`
  final String selectionMode;
  final int? modelTypeId;
  final List<TagNode> nodes;

  const TagSystem({
    required this.id,
    required this.name,
    required this.isHierarchical,
    required this.selectionMode,
    this.modelTypeId,
    this.nodes = const [],
  });

  factory TagSystem.fromJson(Map<String, dynamic> json) {
    List<TagNode> nodes = const [];
    final rawNodes = json['nodes'];
    if (rawNodes is List && rawNodes.isNotEmpty) {
      nodes = rawNodes
          .map((e) => TagNode.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return TagSystem(
      id: json['id'] as int,
      name: json['name'] as String,
      isHierarchical: json['is_hierarchical'] as bool? ??
          json['isHierarchical'] as bool? ??
          false,
      selectionMode: json['selection_mode'] as String? ??
          json['selectionMode'] as String? ??
          'multiple',
      modelTypeId: json['model_type_id'] as int? ?? json['modelTypeId'] as int?,
      nodes: nodes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_hierarchical': isHierarchical,
      'selection_mode': selectionMode,
      if (modelTypeId != null) 'model_type_id': modelTypeId,
      'nodes': nodes.map((n) => n.toJson()).toList(),
    };
  }
}
