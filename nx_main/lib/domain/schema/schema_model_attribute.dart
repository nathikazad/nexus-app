/// One attribute on a KGQL model instance (read path).
class SchemaModelAttribute {
  final int id;
  final String key;
  final String? value;

  const SchemaModelAttribute({
    required this.id,
    required this.key,
    this.value,
  });
}
