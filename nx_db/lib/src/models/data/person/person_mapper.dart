import 'dart:convert';

import 'package:nx_db/kgql.dart' show Model;

import '../../domain/person/person.dart';
import 'person_attr_keys.dart';

/// [Model] ⇄ [Person].
Person personFromModel(Model m) {
  return Person(
    id: m.id,
    name: m.name,
    description: m.description,
    preference: parsePersonPreferenceMap(m),
  );
}

/// Raw `preference` attribute from a Person [Model] as a mutable map.
Map<String, dynamic> parsePersonPreferenceMap(Model? person) {
  if (person == null) return {};
  final raw =
      _attr(person, kPersonAttrPreference) ?? _attr(person, 'Preference');
  if (raw == null) return {};
  if (raw is Map<String, dynamic>) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)));
  }
  if (raw is String) {
    try {
      final d = json.decode(raw) as Object?;
      if (d is Map<String, dynamic>) {
        return Map<String, dynamic>.from(d);
      }
      if (d is Map) {
        return Map<String, dynamic>.from(
            d.map((k, v) => MapEntry(k.toString(), v)));
      }
    } catch (_) {}
  }
  return {};
}

dynamic _attr(Model m, String key) {
  final a = m.attributes;
  if (a == null) return null;
  if (a.containsKey(key)) return a[key];
  final lower = key.toLowerCase();
  for (final e in a.entries) {
    if (e.key.toLowerCase() == lower) return e.value;
  }
  return null;
}
