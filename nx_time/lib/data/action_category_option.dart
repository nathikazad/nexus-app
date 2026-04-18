import 'package:flutter/material.dart';
import 'package:nx_db/nx_db.dart';

import 'model_type_bar_color.dart';

/// One row in the add/edit category picker — matches a KGQL model type (Action subtype).
class ActionCategoryOption {
  const ActionCategoryOption({
    required this.modelTypeId,
    required this.name,
    required this.dotColor,
  });

  final int modelTypeId;
  final String name;
  final Color dotColor;

  /// Display text (same as KGQL `model_type` name for `set_kgql_models`).
  String get label => name;

  factory ActionCategoryOption.fromModel(Model m) {
    return ActionCategoryOption(
      modelTypeId: m.modelTypeId,
      name: m.modelType?.name ?? 'Action',
      dotColor: barColorForModelTypeId(m.modelTypeId),
    );
  }
}
