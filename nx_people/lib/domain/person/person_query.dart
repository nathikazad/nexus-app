import 'package:nx_people/domain/person/person.dart';

class PeopleResultContext {
  const PeopleResultContext({
    required this.type,
    required this.label,
    required this.personIds,
  });

  final String type;
  final String label;
  final List<int> personIds;

  String get title => '$type: $label';
}

class PersonRepository {
  const PersonRepository(this.people);

  final List<Person> people;

  Person byId(int id) => people.firstWhere((person) => person.id == id);

  List<Person> pinned() => people.where((person) => person.pinned).toList();

  List<Person> recent() => <Person>[
    byId(4),
    byId(1),
    byId(2),
    byId(6),
    byId(3),
  ];

  List<Person> followUp() {
    return people.where((person) => person.status == 'Follow up').toList();
  }

  List<Person> search(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const <Person>[];
    return people.where((person) => person.matches(trimmed)).toList();
  }

  PeopleResultContext context(String type, String label) {
    return PeopleResultContext(
      type: type,
      label: label,
      personIds: _filter(type, label).map((person) => person.id).toList(),
    );
  }

  List<Person> peopleFor(PeopleResultContext context) {
    return context.personIds.map(byId).toList();
  }

  int count(String type, String label) => _filter(type, label).length;

  List<Person> _filter(String type, String label) {
    return switch (type) {
      'Search' => search(label),
      'Company' => people.where((person) => person.company == label).toList(),
      'Meeting' => people
          .where((person) => person.meetings.contains(label))
          .toList(),
      'Planned' => people.where((person) => person.planned.contains(label)).toList(),
      'Status' => people.where((person) => person.status == label).toList(),
      _ => people.where((person) => person.tags.contains(label)).toList(),
    };
  }
}
