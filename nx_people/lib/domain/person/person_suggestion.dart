enum PersonSuggestionKind {
  work('work', 'Work'),
  education('education', 'Education');

  const PersonSuggestionKind(this.jsonKey, this.label);

  final String jsonKey;
  final String label;
}

class PersonSuggestions {
  const PersonSuggestions({
    required this.work,
    required this.education,
    this.raw = const <String, dynamic>{},
  });

  static const empty = PersonSuggestions(
    work: <PersonWorkSuggestion>[],
    education: <PersonEducationSuggestion>[],
  );

  final List<PersonWorkSuggestion> work;
  final List<PersonEducationSuggestion> education;
  final Map<String, dynamic> raw;

  bool get isEmpty => work.isEmpty && education.isEmpty;

  bool get hasUnresolved =>
      work.any((item) => !item.isResolved) ||
      education.any((item) => !item.isResolved);

  int get unresolvedCount =>
      work.where((item) => !item.isResolved).length +
      education.where((item) => !item.isResolved).length;

  factory PersonSuggestions.fromJson(Object? raw) {
    final map = _mapFromObject(raw);
    if (map.isEmpty) return PersonSuggestions.empty;
    return PersonSuggestions(
      raw: map,
      work: [
        for (final row in _mapList(map['work']))
          PersonWorkSuggestion.fromJson(row),
      ],
      education: [
        for (final row in _mapList(map['education']))
          PersonEducationSuggestion.fromJson(row),
      ],
    );
  }

  PersonSuggestions resolve({
    required PersonSuggestionKind kind,
    required int index,
    required PersonSuggestionResolution selected,
  }) {
    switch (kind) {
      case PersonSuggestionKind.work:
        if (index < 0 || index >= work.length) return this;
        final next = List<PersonWorkSuggestion>.of(work);
        next[index] = next[index].copyWith(selected: selected);
        return copyWith(work: next);
      case PersonSuggestionKind.education:
        if (index < 0 || index >= education.length) return this;
        final next = List<PersonEducationSuggestion>.of(education);
        next[index] = next[index].copyWith(selected: selected);
        return copyWith(education: next);
    }
  }

  PersonSuggestions copyWith({
    List<PersonWorkSuggestion>? work,
    List<PersonEducationSuggestion>? education,
  }) {
    return PersonSuggestions(
      raw: raw,
      work: work ?? this.work,
      education: education ?? this.education,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...raw,
      'work': [for (final item in work) item.toJson()],
      'education': [for (final item in education) item.toJson()],
    };
  }
}

class PersonSuggestionCandidate {
  const PersonSuggestionCandidate({
    required this.id,
    required this.name,
    required this.percentage,
  });

  final int id;
  final String name;
  final int percentage;

  bool get isValid => id > 0 && name.trim().isNotEmpty;

  factory PersonSuggestionCandidate.fromJson(Object? raw) {
    final map = _mapFromObject(raw);
    return PersonSuggestionCandidate(
      id: _intFromObject(map['id']) ?? 0,
      name: _stringFromObject(map['name']),
      percentage:
          _intFromObject(map['percentage']) ??
          _percentageFromSimilarity(map['name_similarity']) ??
          _percentageFromSimilarity(map['name_word_similarity']) ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'id': id, 'percentage': percentage};
  }
}

class PersonSuggestionResolution {
  const PersonSuggestionResolution({
    required this.id,
    required this.name,
    required this.source,
  });

  final int id;
  final String name;
  final String source;

  factory PersonSuggestionResolution.fromJson(Object? raw) {
    final map = _mapFromObject(raw);
    final id = _intFromObject(map['id']);
    final name = _stringFromObject(map['name']);
    if (id == null || id <= 0 || name.isEmpty) {
      return const PersonSuggestionResolution(id: 0, name: '', source: '');
    }
    return PersonSuggestionResolution(
      id: id,
      name: name,
      source: _stringFromObject(map['source']),
    );
  }

  bool get isValid => id > 0 && name.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, if (source.isNotEmpty) 'source': source};
  }
}

class PersonWorkSuggestion {
  const PersonWorkSuggestion({
    required this.company,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.notes,
    required this.candidates,
    this.selected,
    this.raw = const <String, dynamic>{},
  });

  final String company;
  final String title;
  final String startDate;
  final String? endDate;
  final String notes;
  final List<PersonSuggestionCandidate> candidates;
  final PersonSuggestionResolution? selected;
  final Map<String, dynamic> raw;

  String get organizationName => company;
  String get detail => title;
  bool get isResolved => selected?.isValid ?? false;

  factory PersonWorkSuggestion.fromJson(Object? raw) {
    final map = _mapFromObject(raw);
    return PersonWorkSuggestion(
      raw: map,
      company: _stringFromObject(map['company']),
      title: _stringFromObject(map['title']),
      startDate: _stringFromObject(map['start_date']),
      endDate: _nullableStringFromObject(map['end_date']),
      notes: _stringFromObject(map['notes']),
      candidates: _candidateList(map['suggestions']),
      selected: _resolutionFromObject(map['selected']),
    );
  }

  PersonWorkSuggestion copyWith({PersonSuggestionResolution? selected}) {
    return PersonWorkSuggestion(
      raw: raw,
      company: company,
      title: title,
      startDate: startDate,
      endDate: endDate,
      notes: notes,
      candidates: candidates,
      selected: selected ?? this.selected,
    );
  }

  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.from(raw);
    json['company'] = company;
    json['title'] = title;
    json['start_date'] = startDate;
    json['end_date'] = endDate;
    json['notes'] = notes;
    json['suggestions'] = [for (final item in candidates) item.toJson()];
    if (selected?.isValid ?? false) {
      json['selected'] = selected!.toJson();
    } else {
      json.remove('selected');
    }
    return json;
  }
}

class PersonEducationSuggestion {
  const PersonEducationSuggestion({
    required this.school,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.notes,
    required this.candidates,
    this.selected,
    this.raw = const <String, dynamic>{},
  });

  final String school;
  final String type;
  final String startDate;
  final String? endDate;
  final String notes;
  final List<PersonSuggestionCandidate> candidates;
  final PersonSuggestionResolution? selected;
  final Map<String, dynamic> raw;

  String get organizationName => school;
  String get detail => type;
  bool get isResolved => selected?.isValid ?? false;

  factory PersonEducationSuggestion.fromJson(Object? raw) {
    final map = _mapFromObject(raw);
    return PersonEducationSuggestion(
      raw: map,
      school: _stringFromObject(map['school']),
      type: _stringFromObject(map['type']),
      startDate: _stringFromObject(map['start_date']),
      endDate: _nullableStringFromObject(map['end_date']),
      notes: _stringFromObject(map['notes']),
      candidates: _candidateList(map['suggestions']),
      selected: _resolutionFromObject(map['selected']),
    );
  }

  PersonEducationSuggestion copyWith({PersonSuggestionResolution? selected}) {
    return PersonEducationSuggestion(
      raw: raw,
      school: school,
      type: type,
      startDate: startDate,
      endDate: endDate,
      notes: notes,
      candidates: candidates,
      selected: selected ?? this.selected,
    );
  }

  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.from(raw);
    json['school'] = school;
    json['type'] = type;
    json['start_date'] = startDate;
    json['end_date'] = endDate;
    json['notes'] = notes;
    json['suggestions'] = [for (final item in candidates) item.toJson()];
    if (selected?.isValid ?? false) {
      json['selected'] = selected!.toJson();
    } else {
      json.remove('selected');
    }
    return json;
  }
}

List<PersonSuggestionCandidate> _candidateList(Object? raw) {
  return [
    for (final item in _mapList(raw))
      if (PersonSuggestionCandidate.fromJson(item) case final candidate
          when candidate.isValid)
        candidate,
  ];
}

PersonSuggestionResolution? _resolutionFromObject(Object? raw) {
  final resolution = PersonSuggestionResolution.fromJson(raw);
  return resolution.isValid ? resolution : null;
}

List<Map<String, dynamic>> _mapList(Object? raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return [
    for (final item in raw)
      if (_mapFromObject(item) case final map when map.isNotEmpty) map,
  ];
}

Map<String, dynamic> _mapFromObject(Object? raw) {
  if (raw is! Map) return const <String, dynamic>{};
  return raw.map((key, value) => MapEntry(key.toString(), value));
}

String _stringFromObject(Object? raw) {
  if (raw == null) return '';
  return raw.toString().trim();
}

String? _nullableStringFromObject(Object? raw) {
  final value = _stringFromObject(raw);
  return value.isEmpty ? null : value;
}

int? _intFromObject(Object? raw) {
  if (raw is int) return raw;
  if (raw is double) return raw.round();
  return int.tryParse(raw?.toString() ?? '');
}

int? _percentageFromSimilarity(Object? raw) {
  if (raw is int) return raw.clamp(0, 100);
  if (raw is double) return (raw * 100).round().clamp(0, 100);
  final parsed = double.tryParse(raw?.toString() ?? '');
  return parsed == null ? null : (parsed * 100).round().clamp(0, 100);
}
