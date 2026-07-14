import 'dart:convert';

import 'package:nx_db/kgql.dart';
import 'package:nx_people/data/person/person_attr_keys.dart';
import 'package:nx_people/domain/person/person.dart';

const String _meetStartTimeAttr = 'start_time';
const String _meetActualStartTimeAttr = 'actual_start_time';
const String _meetScheduledStartTimeAttr = 'scheduled_start_time';
const String _meetPlanningStatusAttr = 'planning_status';
const String kWorkForRelationName = 'work_for';
const String kStudyAtRelationName = 'study_at';

Person personFromModel(Model model) {
  final tags = model.tags ?? const <String, List<String>>{};
  final tagsBySystem = _tagsBySystem(tags);
  final tagValues = [for (final entry in tagsBySystem.entries) ...entry.value];
  final status =
      model.attrString(kPersonAttrStatus) ??
      tags[kPeopleStatusTagSystem]?.firstOrNull ??
      'Active';
  final company =
      _mostRecentNamedRelatedName(model, kWorkForRelationName) ??
      model.attrString(kPersonAttrCompany) ??
      _firstRelatedName(model, 'Company') ??
      _firstRelatedName(model, 'Place') ??
      '';
  final location =
      model.attrString(kPersonAttrLocation) ??
      tags[kPeopleLocationTagSystem]?.firstOrNull ??
      '';
  final summary = model.description ?? 'No summary yet.';

  return Person(
    id: model.id,
    name: model.name,
    initials: _initials(model.name),
    company: company,
    role: model.attrString(kPersonAttrRole) ?? '',
    location: location,
    status: status,
    statusColor: _statusColor(status),
    lastContact: model.attrString(kPersonAttrLastContact) ?? 'Unknown',
    updatedAt: model.updatedAt ?? '',
    nextFollowUp: model.attrString(kPersonAttrNextFollowUp) ?? 'None',
    pinned: model.attrBool(kPersonAttrPinned) ?? false,
    email: model.attrString(kPersonAttrEmail) ?? '',
    phone: model.attrString(kPersonAttrPhone) ?? '',
    imageUrl: model.attrString(kPersonAttrImageUrl) ?? '',
    tags: tagValues.toSet().toList()..sort(),
    tagsBySystem: tagsBySystem,
    meetings: _actualMeetingNames(model),
    planned: _plannedMeetingNames(model),
    summary: summary,
    desires: _stringListFromRaw(model.attributes?[kPersonAttrDesires]),
    currentThreads: _threadsFromRaw(
      model.attributes?[kPersonAttrCurrentThreads],
    ),
    logs: _logsFromRaw(model.attributes?[kPersonAttrLogs]),
    relatedIds: _relatedPeople(model),
    contacts: _contacts(model),
    workRelations: _namedBackgroundRelations(
      model,
      relationName: kWorkForRelationName,
    ),
    educationRelations: [
      ..._namedBackgroundRelations(model, relationName: kStudyAtRelationName),
      ..._backgroundRelations(model, const <String>[
        'School',
        'University',
        'Education',
      ]),
    ],
    suggestions: PersonSuggestions.fromJson(model.attributes?['suggestion']),
  );
}

Map<String, List<String>> _tagsBySystem(Map<String, List<String>> raw) {
  return {
    for (final entry in raw.entries)
      if (entry.key != kPeopleStatusTagSystem)
        entry.key: entry.value.toSet().toList()..sort(),
  };
}

Map<String, dynamic> personFetchStruct(ModelType schema) {
  return {
    ...buildKgqlStructFromSchema(
      schema,
      extraTopLevel: const [
        'id',
        'name',
        'description',
        'created_at',
        'updated_at',
        'model_type_id',
        'suggestion',
      ],
    ),
    'tags': true,
    'relations': {
      'relation_id': true,
      'model_id': true,
      'model_type': true,
      'name': true,
      'description': true,
      'relation_name': true,
      'relation_description': true,
      'relation_attributes': {'key': true, 'value': true, 'value_type': true},
    },
    'Company': {'id': true, 'name': true, 'description': true},
    'School': {'id': true, 'name': true, 'description': true},
    'University': {'id': true, 'name': true, 'description': true},
    'Education': {'id': true, 'name': true, 'description': true},
    'Meeting': {'id': true, 'name': true, 'description': true},
    'Meet': {
      'id': true,
      'name': true,
      'description': true,
      _meetStartTimeAttr: true,
      _meetActualStartTimeAttr: true,
      _meetScheduledStartTimeAttr: true,
      _meetPlanningStatusAttr: true,
    },
    'Place': {'id': true, 'name': true, 'description': true},
    'Contact': {
      'id': true,
      'name': true,
      'description': true,
      'type': true,
      'value': true,
      'url': true,
      'link': true,
    },
    'Person': {'id': true, 'name': true, 'description': true},
  };
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

PersonStatusColor _statusColor(String status) {
  final normalized = status.toLowerCase();
  if (normalized.contains('follow')) return PersonStatusColor.amber;
  if (normalized.contains('dormant')) return PersonStatusColor.blue;
  if (normalized.contains('blocked') || normalized.contains('cold')) {
    return PersonStatusColor.red;
  }
  return PersonStatusColor.green;
}

String? _firstRelatedName(Model model, String type) {
  final names = _relatedNames(model, type);
  return names.isEmpty ? null : names.first;
}

String? _mostRecentNamedRelatedName(Model model, String relationName) {
  final sourceRows = model.relationsList ?? const <Relation>[];
  final rows = [
    for (final row in sourceRows)
      if (row.relationName == relationName &&
          (row.name?.trim().isNotEmpty ?? false))
        row,
  ];
  rows.sort(_compareRelationRowsByStartDateDesc);
  return rows.isEmpty ? null : rows.first.name!.trim();
}

List<String> _relatedNames(Model model, String type) {
  final rows = model.relations?[type] ?? const <Model>[];
  return rows.map((row) => row.name).where((name) => name.isNotEmpty).toList()
    ..sort();
}

List<PersonBackgroundRelation> _namedBackgroundRelations(
  Model model, {
  required String relationName,
}) {
  final rows = <PersonBackgroundRelation>[
    for (final row in model.relationsList ?? const <Relation>[])
      if (row.relationName == relationName &&
          (row.name?.trim().isNotEmpty ?? false))
        PersonBackgroundRelation(
          type: row.modelType,
          id: row.modelId,
          relationId: row.relationId,
          relationName: row.relationName ?? '',
          name: row.name!.trim(),
          description: row.description?.trim() ?? '',
          relationDescription: row.relationDescription?.trim() ?? '',
          attributes: row.relationAttributes ?? const <String, dynamic>{},
        ),
  ];
  rows.sort(_compareBackgroundRelationsByStartDateDesc);
  return rows;
}

int _compareRelationRowsByStartDateDesc(Relation a, Relation b) {
  final aStart = _relationStartDate(a.relationAttributes);
  final bStart = _relationStartDate(b.relationAttributes);
  final dateCompare = _compareNullableDatesDesc(aStart, bStart);
  if (dateCompare != 0) return dateCompare;
  return (a.name ?? '').compareTo(b.name ?? '');
}

int _compareBackgroundRelationsByStartDateDesc(
  PersonBackgroundRelation a,
  PersonBackgroundRelation b,
) {
  final aStart = _relationStartDate(a.attributes);
  final bStart = _relationStartDate(b.attributes);
  final dateCompare = _compareNullableDatesDesc(aStart, bStart);
  if (dateCompare != 0) return dateCompare;
  return a.name.compareTo(b.name);
}

int _compareNullableDatesDesc(DateTime? a, DateTime? b) {
  if (a != null && b != null) return b.compareTo(a);
  if (a != null) return -1;
  if (b != null) return 1;
  return 0;
}

DateTime? _relationStartDate(Map<String, dynamic>? attributes) {
  final raw = attributes?['start_date'];
  if (raw == null) return null;
  final value = raw.toString().trim();
  return DateTime.tryParse(value) ??
      DateTime.tryParse(value.replaceFirst(' ', 'T'));
}

List<PersonBackgroundRelation> _backgroundRelations(
  Model model,
  List<String> types,
) {
  final rows = <PersonBackgroundRelation>[
    for (final type in types)
      for (final row in model.relations?[type] ?? const <Model>[])
        if (row.name.trim().isNotEmpty)
          PersonBackgroundRelation(
            type: type,
            id: row.id,
            name: row.name.trim(),
            description: row.description?.trim() ?? '',
          ),
  ];
  rows.sort((a, b) {
    final typeCompare = a.type.compareTo(b.type);
    if (typeCompare != 0) return typeCompare;
    return a.name.compareTo(b.name);
  });
  return rows;
}

List<String> _actualMeetingNames(Model model) {
  final legacy = _relatedNames(model, 'Meeting');
  final meetRows = model.relations?['Meet'] ?? const <Model>[];
  final meetNames = [
    for (final meet in meetRows)
      if (_hasActualMeetingTime(meet) && !_hasInactivePlanningStatus(meet))
        meet.name,
  ].where((name) => name.isNotEmpty);
  return {...legacy, ...meetNames}.toList()..sort();
}

List<String> _plannedMeetingNames(Model model) {
  final meetRows = model.relations?['Meet'] ?? const <Model>[];
  return {
    for (final meet in meetRows)
      if (_isPlannedMeet(meet) && meet.name.isNotEmpty) meet.name,
  }.toList()..sort();
}

List<String> _stringListFromRaw(Object? raw) {
  if (raw == null) return const <String>[];
  if (raw is List) {
    return raw
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(trimmed);
      return _stringListFromRaw(decoded);
    } on FormatException {
      return [trimmed];
    }
  }
  return const <String>[];
}

bool _hasActualMeetingTime(Model meet) {
  return meet.attrDateTime(_meetStartTimeAttr) != null ||
      meet.attrDateTime(_meetActualStartTimeAttr) != null;
}

bool _isPlannedMeet(Model meet) {
  return meet.attrDateTime(_meetScheduledStartTimeAttr) != null &&
      !_hasActualMeetingTime(meet) &&
      _planningStatus(meet) == 'planned';
}

bool _hasInactivePlanningStatus(Model model) {
  final status = _planningStatus(model);
  return status == 'skipped' || status == 'cancelled';
}

String _planningStatus(Model model) {
  return model.attrString(_meetPlanningStatusAttr)?.toLowerCase() ?? 'attended';
}

List<int> _relatedPeople(Model model) {
  final rows = model.relations?[kPersonModelTypeName] ?? const <Model>[];
  return rows
      .map((row) => row.id)
      .where((id) => id != model.id)
      .toSet()
      .toList();
}

List<PersonContact> _contacts(Model model) {
  final relationRows = [
    for (final relation in model.relationsList ?? const <Relation>[])
      if (relation.modelType == 'Contact' &&
          relation.relationName == 'has_contact')
        relation,
  ];
  if (relationRows.isEmpty) return const <PersonContact>[];

  final contactRows = {
    for (final contact in model.relations?['Contact'] ?? const <Model>[])
      contact.id: contact,
  };

  final contacts = <PersonContact>[
    for (final relation in relationRows)
      if (_contactFromRelation(relation, contactRows[relation.modelId])
          case final contact?)
        contact,
  ];
  contacts.sort((a, b) {
    final typeCompare = a.type.compareTo(b.type);
    if (typeCompare != 0) return typeCompare;
    return a.value.compareTo(b.value);
  });
  return contacts;
}

PersonContact? _contactFromRelation(Relation relation, Model? contact) {
  final name = contact?.name.trim().isNotEmpty == true
      ? contact!.name.trim()
      : relation.name?.trim() ?? '';
  final type =
      _contactStringAttr(contact, 'type') ?? _inferContactType(name) ?? '';
  final value =
      _contactStringAttr(contact, 'value') ??
      _contactValueFromName(name, type) ??
      '';
  final url =
      _contactStringAttr(contact, 'url') ??
      _contactStringAttr(contact, 'link') ??
      '';
  if (type.isEmpty && value.isEmpty && url.isEmpty && name.isEmpty) {
    return null;
  }
  return PersonContact(
    id: relation.modelId,
    type: type,
    value: value,
    name: name,
    description: contact?.description?.trim() ?? relation.description ?? '',
    url: url,
  );
}

String? _contactStringAttr(Model? contact, String key) {
  final raw = contact?.attributes?[key];
  if (raw == null || raw is List || raw is Map) return null;
  final value = raw.toString().trim();
  return value.isEmpty ? null : value;
}

String? _inferContactType(String name) {
  final lower = name.toLowerCase();
  if (lower.startsWith('linkedin:')) return 'linkedin';
  if (lower.startsWith('email:') || lower.contains('@')) return 'email';
  if (lower.startsWith('phone:') || lower.startsWith('tel:')) return 'phone';
  if (lower.startsWith('url:') || lower.startsWith('link:')) return 'link';
  return null;
}

String? _contactValueFromName(String name, String type) {
  final separator = name.indexOf(':');
  if (separator >= 0 && separator + 1 < name.length) {
    final value = name.substring(separator + 1).trim();
    return value.isEmpty ? null : value;
  }
  if (type == 'email' && name.contains('@')) return name;
  return null;
}

List<PersonThread> _threadsFromRaw(Object? raw) {
  final rows = _listOfMaps(raw);
  return [
    for (final row in rows)
      PersonThread(
        title: row['title']?.toString() ?? 'Thread',
        body: row['body']?.toString() ?? row['description']?.toString() ?? '',
      ),
  ];
}

List<PersonLog> _logsFromRaw(Object? raw) {
  final rows = _listOfMaps(raw);
  return [
    for (final row in rows)
      PersonLog(
        time: row['time']?.toString() ?? row['date']?.toString() ?? '',
        body: row['body']?.toString() ?? row['description']?.toString() ?? '',
      ),
  ];
}

List<Map<String, dynamic>> _listOfMaps(Object? raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
  return const <Map<String, dynamic>>[];
}
