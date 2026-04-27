import 'dart:convert';

import 'package:nx_db/kgql.dart';
import 'package:nx_cooking/data/recipe/recipe_attr_keys.dart';

/// Resolves display amount: prefers `has_ingredient.quantity` (string), else legacy Item.description prefix.
String ingredientAmountDisplay(Relation? rel, String? itemDescription) {
  final fromRel = _relationString(rel, kHasIngredientRelationAttrQuantity);
  if (fromRel != null && fromRel.isNotEmpty) {
    return fromRel;
  }
  return _amountFromItemDescriptionLegacy(itemDescription);
}

String? ingredientGroupName(Relation? rel) =>
    _nonEmptyRelationString(rel, kHasIngredientRelationAttrGroupName);

String? ingredientPreparation(Relation? rel) =>
    _nonEmptyRelationString(rel, kHasIngredientRelationAttrNotes);

Relation? relationForItemModel(List<Relation>? relList, int itemId) {
  if (relList == null) {
    return null;
  }
  for (final r in relList) {
    if (r.modelId == itemId && r.modelType == kItemModelTypeName) {
      return r;
    }
  }
  return null;
}

/// Parses `Recipe.crawler_payload` (Map or JSON string from GraphQL).
Map<String, dynamic>? crawlerPayloadFromModelAttributes(
  Map<String, dynamic>? attributes,
) {
  if (attributes == null) {
    return null;
  }
  final raw = attributes[kRecipeAttrCrawlerPayload];
  if (raw == null) {
    return null;
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(t);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }
  }
  return null;
}

String? _relationString(Relation? rel, String key) {
  final raw = rel?.relationAttributes?[key];
  return _stringFromDynamic(raw);
}

String? _nonEmptyRelationString(Relation? rel, String key) {
  final s = _relationString(rel, key)?.trim();
  if (s == null || s.isEmpty) {
    return null;
  }
  return s;
}

String? _stringFromDynamic(dynamic raw) {
  if (raw == null) {
    return null;
  }
  if (raw is String) {
    return raw;
  }
  return raw.toString();
}

String _amountFromItemDescriptionLegacy(String? description) {
  if (description == null) {
    return '';
  }
  final t = description.trim();
  if (t.isEmpty) {
    return '';
  }
  final idx = t.indexOf(' · ');
  if (idx == -1) {
    return t;
  }
  return t.substring(0, idx).trim();
}
