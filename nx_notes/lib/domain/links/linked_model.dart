class LinkedModel {
  const LinkedModel({
    required this.id,
    required this.name,
    required this.modelType,
    this.relationId,
  });

  final int id;
  final String name;
  final String modelType;
  final int? relationId;
}
