import 'package:flutter/material.dart' hide Action;

import 'package:nx_time/core/theme/action_color_palette.dart';
import 'package:nx_time/domain/action/action.dart';

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

  factory ActionCategoryOption.fromAction(Action a) {
    return ActionCategoryOption(
      modelTypeId: a.modelTypeId,
      name: a.modelTypeName ?? 'Action',
      dotColor: barColorForModelTypeId(a.modelTypeId),
    );
  }
}
