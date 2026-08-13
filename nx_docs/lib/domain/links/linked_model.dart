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

enum LinkableModelType {
  project('project', 'Project'),
  person('person', 'Person'),
  company('company', 'Company'),
  document('document', 'Document');

  const LinkableModelType(this.command, this.kgqlName);

  final String command;
  final String kgqlName;

  static LinkableModelType? fromCommand(String command) {
    final normalized = command.trim().toLowerCase();
    for (final type in values) {
      if (type.command == normalized) {
        return type;
      }
    }
    return null;
  }
}
