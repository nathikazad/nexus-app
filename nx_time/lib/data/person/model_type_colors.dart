import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/person.dart' show Person, PersonRepository;

import 'package:nx_time/core/theme/action_color_palette.dart';
import 'package:nx_time/domain/action/action_subtype_option.dart';

/// Key inside Person `preference` JSON for per–model-type hex colors.
const kPrefModelTypeColors = 'model_type_colors';

/// `"ModelTypeName" -> "#RRGGBB"` from [preference] root (Person JSON).
Map<String, String> readModelTypeColorHexByName(
  Map<String, dynamic> preference,
) {
  final raw = preference[kPrefModelTypeColors];
  if (raw is! Map) return {};
  final out = <String, String>{};
  for (final e in raw.entries) {
    final v = e.value;
    if (v is String && v.isNotEmpty) {
      out[e.key.toString()] = v;
    } else if (v != null) {
      out[e.key.toString()] = v.toString();
    }
  }
  return out;
}

/// Merges one [kPrefModelTypeColors] entry; preserves unrelated `preference` keys.
Future<Person> setModelTypeColor({
  required PersonRepository repo,
  required Person person,
  required String modelTypeName,
  required String hex,
}) async {
  final merged = Map<String, dynamic>.from(person.preference);
  final existing = readModelTypeColorHexByName(merged);
  final next = Map<String, String>.from(existing)..[modelTypeName] = hex;
  merged[kPrefModelTypeColors] = next;
  return repo.updatePreference(person, merged);
}

/// Seeds any missing action subtype names with default palette colors.
Future<Person> seedMissingModelTypeColors({
  required PersonRepository repo,
  required Person person,
  required List<ActionSubtypeOption> subtypes,
}) async {
  if (subtypes.isEmpty) return person;
  final merged = Map<String, dynamic>.from(person.preference);
  final map = Map<String, String>.from(readModelTypeColorHexByName(merged));
  var changed = false;
  for (final t in subtypes) {
    if (!map.containsKey(t.name)) {
      map[t.name] = hexFromColor(barColorForModelTypeId(t.id));
      changed = true;
    }
  }
  if (!changed) return person;
  merged[kPrefModelTypeColors] = map;
  return repo.updatePreference(person, merged);
}

/// Resolved colors for Action model types: overrides from Person [kPrefModelTypeColors]
/// when present, else [barColorForModelTypeId].
class ModelTypeColors {
  const ModelTypeColors._(this._hexByName);

  /// No persisted overrides; always uses [barColorForModelTypeId].
  static const ModelTypeColors fallback = ModelTypeColors._({});

  /// Build from the root Person `preference` map.
  factory ModelTypeColors.fromPreference(Map<String, dynamic> preference) {
    return ModelTypeColors._(readModelTypeColorHexByName(preference));
  }

  final Map<String, String> _hexByName;

  /// Visible for tests and debugging.
  Map<String, String> get hexByModelTypeName => Map<String, String>.unmodifiable(_hexByName);

  Color forName(String? name) {
    if (name == null || name.isEmpty) {
      return barColorForModelTypeId(0);
    }
    final h = _hexByName[name];
    if (h != null && h.isNotEmpty) {
      return colorFromHex(h);
    }
    return barColorForModelTypeId(0);
  }

  /// Prefer [name] (KGQL `model_type.name`) for lookup; falls back to [barColorForModelTypeId].
  Color forId(int modelTypeId, {String? name}) {
    if (name != null && name.isNotEmpty) {
      final h = _hexByName[name];
      if (h != null && h.isNotEmpty) {
        return colorFromHex(h);
      }
    }
    return barColorForModelTypeId(modelTypeId);
  }
}

/// Sync read for widgets while [modelTypeColorsProvider] may still be loading.
///
/// Returns the last successful value during refetch, so widgets don't flash to
/// the fallback palette.
ModelTypeColors modelTypeColorsOrFallback(AsyncValue<ModelTypeColors> async) {
  return async.asData?.value ?? ModelTypeColors.fallback;
}
