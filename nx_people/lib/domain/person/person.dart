import 'package:nx_people/domain/person/person_suggestion.dart';

export 'package:nx_people/domain/person/person_suggestion.dart';

class Person {
  const Person({
    required this.id,
    required this.name,
    required this.initials,
    required this.company,
    required this.role,
    required this.location,
    required this.status,
    required this.statusColor,
    required this.lastContact,
    required this.updatedAt,
    required this.nextFollowUp,
    required this.pinned,
    required this.email,
    required this.phone,
    required this.tags,
    required this.meetings,
    required this.planned,
    required this.summary,
    required this.currentThreads,
    required this.logs,
    required this.relatedIds,
    this.imageUrl = '',
    this.workRelations = const <PersonBackgroundRelation>[],
    this.educationRelations = const <PersonBackgroundRelation>[],
    this.suggestions = PersonSuggestions.empty,
  });

  final int id;
  final String name;
  final String initials;
  final String company;
  final String role;
  final String location;
  final String status;
  final PersonStatusColor statusColor;
  final String lastContact;
  final String updatedAt;
  final String nextFollowUp;
  final bool pinned;
  final String email;
  final String phone;
  final List<String> tags;
  final List<String> meetings;
  final List<String> planned;
  final String summary;
  final List<PersonThread> currentThreads;
  final List<PersonLog> logs;
  final List<int> relatedIds;
  final String imageUrl;
  final List<PersonBackgroundRelation> workRelations;
  final List<PersonBackgroundRelation> educationRelations;
  final PersonSuggestions suggestions;

  bool matches(String query) {
    final normalized = query.toLowerCase();
    return <String>[
      name,
      company,
      role,
      location,
      status,
      summary,
      email,
      phone,
      ...tags,
      for (final relation in workRelations) relation.name,
      for (final relation in educationRelations) relation.name,
    ].join(' ').toLowerCase().contains(normalized);
  }

  Person copyWith({
    String? name,
    String? initials,
    String? company,
    String? role,
    String? location,
    String? status,
    PersonStatusColor? statusColor,
    String? lastContact,
    String? updatedAt,
    String? nextFollowUp,
    bool? pinned,
    String? email,
    String? phone,
    List<String>? tags,
    List<String>? meetings,
    List<String>? planned,
    String? summary,
    List<PersonThread>? currentThreads,
    List<PersonLog>? logs,
    List<int>? relatedIds,
    String? imageUrl,
    List<PersonBackgroundRelation>? workRelations,
    List<PersonBackgroundRelation>? educationRelations,
    PersonSuggestions? suggestions,
  }) {
    return Person(
      id: id,
      name: name ?? this.name,
      initials: initials ?? this.initials,
      company: company ?? this.company,
      role: role ?? this.role,
      location: location ?? this.location,
      status: status ?? this.status,
      statusColor: statusColor ?? this.statusColor,
      lastContact: lastContact ?? this.lastContact,
      updatedAt: updatedAt ?? this.updatedAt,
      nextFollowUp: nextFollowUp ?? this.nextFollowUp,
      pinned: pinned ?? this.pinned,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      tags: tags ?? this.tags,
      meetings: meetings ?? this.meetings,
      planned: planned ?? this.planned,
      summary: summary ?? this.summary,
      currentThreads: currentThreads ?? this.currentThreads,
      logs: logs ?? this.logs,
      relatedIds: relatedIds ?? this.relatedIds,
      imageUrl: imageUrl ?? this.imageUrl,
      workRelations: workRelations ?? this.workRelations,
      educationRelations: educationRelations ?? this.educationRelations,
      suggestions: suggestions ?? this.suggestions,
    );
  }
}

class PersonBackgroundRelation {
  const PersonBackgroundRelation({
    required this.type,
    required this.name,
    this.id = 0,
    this.relationId = 0,
    this.relationName = '',
    this.description = '',
    this.relationDescription = '',
    this.attributes = const <String, dynamic>{},
  });

  final String type;
  final String name;
  final int id;
  final int relationId;
  final String relationName;
  final String description;
  final String relationDescription;
  final Map<String, dynamic> attributes;
}

class PersonThread {
  const PersonThread({required this.title, required this.body});

  final String title;
  final String body;
}

class PersonLog {
  const PersonLog({required this.time, required this.body});

  final String time;
  final String body;
}

enum PersonStatusColor { green, blue, amber, red }
