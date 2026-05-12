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

abstract class PersonRepository {
  Future<List<Person>> listRecent({int limit = 20});
  Future<List<Person>> listPinned({int limit = 20});
  Future<List<Person>> listFollowUp({int limit = 20});
  Future<List<Person>> search(String query);
  Future<Person?> getById(int id);
  Future<List<PeopleTagSystem>> listTagSystems();
  Future<PeopleResultContext> context(String type, String label);
  Future<List<Person>> peopleFor(PeopleResultContext context);
  Future<int> count(String type, String label);
  Future<List<String>> listCompanies();
  Future<List<String>> listMeetings();
  Future<List<String>> listPlanned();
}

class PeopleTagSystem {
  const PeopleTagSystem({
    required this.name,
    required this.tags,
    this.hierarchical = false,
    this.exclusive = false,
  });

  final String name;
  final List<String> tags;
  final bool hierarchical;
  final bool exclusive;
}
