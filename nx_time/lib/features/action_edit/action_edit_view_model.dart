import 'package:nx_time/data/action_category_option.dart';
import 'package:nx_time/domain/action/action.dart';

/// Validation and [Action] construction for [ActionEditPage] (pure Dart).
class ActionEditViewModel {
  ActionEditViewModel._();

  /// User-visible snackbar message when save should not proceed; null if OK.
  static String? snackbarErrorForSave({
    required String nameTrimmed,
    required bool isCreate,
    ActionCategoryOption? categoryCreate,
  }) {
    if (nameTrimmed.isEmpty) return 'Enter a name';
    if (isCreate && categoryCreate == null) {
      return 'Choose a type, start, and end';
    }
    return null;
  }

  /// Ensures end is strictly after start (overnight block rolls to next day).
  static DateTime normalizeEndAfterStart(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return end.add(const Duration(days: 1));
    return end;
  }

  static Action buildCreateAction({
    required String name,
    required String? notes,
    required ActionCategoryOption category,
    required DateTime start,
    required DateTime end,
  }) {
    return Action(
      id: 0,
      name: name,
      description: notes,
      modelTypeId: category.modelTypeId,
      modelTypeName: category.name,
      startTime: start,
      endTime: end,
    );
  }

  static Action buildUpdateAction({
    required Action initial,
    required String name,
    required String? notes,
    required ActionCategoryOption category,
    required DateTime start,
    required DateTime end,
  }) {
    return Action(
      id: initial.id,
      name: name,
      description: notes,
      modelTypeId: category.modelTypeId,
      modelTypeName: category.name,
      startTime: start,
      endTime: end,
    );
  }

  /// Pass to [ActionRepository.update] when the concrete KGQL type changed.
  static String? modelTypeNameIfChanged(
    Action initial,
    ActionCategoryOption category,
  ) {
    return category.name != (initial.modelTypeName ?? '') ? category.name : null;
  }
}
