/// A Person row: identity plus JSON `preference`.
class Person {
  const Person({
    required this.id,
    required this.name,
    this.description,
    this.preference = const <String, dynamic>{},
  });

  final int id;
  final String name;
  final String? description;
  final Map<String, dynamic> preference;

  Person copyWith({
    int? id,
    String? name,
    String? description,
    Map<String, dynamic>? preference,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      preference: preference ?? this.preference,
    );
  }
}
