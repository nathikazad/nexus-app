import 'dart:convert';

import 'package:nx_db/kgql.dart' show Model;

import '../../domain/person/person.dart';
import 'person_attr_keys.dart';

/// [Model] ⇄ [Person].
///
/// [preference] comes from `users.preferences`, not a KGQL Person attribute.
Person personFromModel(
  Model m, {
  Map<String, dynamic> preference = const <String, dynamic>{},
}) {
  return Person(
    id: m.id,
    name: m.name,
    description: m.description,
    preference: Map<String, dynamic>.from(preference),
  );
}

/// Legacy raw `preference` attribute from a Person [Model] as a mutable map.
///
/// New reads and writes should use `users.preferences`; this is kept only for
/// older tests/tools that may inspect historical payloads.
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
