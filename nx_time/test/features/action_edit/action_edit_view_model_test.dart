import 'package:flutter/material.dart' hide Action;
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/data/action_category_option.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/features/action_edit/action_edit_view_model.dart';

void main() {
  test('snackbarErrorForSave', () {
    expect(
      ActionEditViewModel.snackbarErrorForSave(
        nameTrimmed: '',
        isCreate: true,
      ),
      isNotNull,
    );
    expect(
      ActionEditViewModel.snackbarErrorForSave(
        nameTrimmed: 'x',
        isCreate: true,
        categoryCreate: null,
      ),
      isNotNull,
    );
    expect(
      ActionEditViewModel.snackbarErrorForSave(
        nameTrimmed: 'x',
        isCreate: true,
        categoryCreate: const ActionCategoryOption(
          modelTypeId: 1,
          name: 'Meet',
          dotColor: Color(0xFF000000),
        ),
      ),
      isNull,
    );
  });

  test('normalizeEndAfterStart rolls overnight end forward', () {
    final start = DateTime(2026, 4, 18, 22, 0);
    final end = DateTime(2026, 4, 18, 6, 0);
    final n = ActionEditViewModel.normalizeEndAfterStart(start, end);
    expect(n.day, 19);
    expect(n.isAfter(start), isTrue);
  });

  test('modelTypeNameIfChanged', () {
    const initial = Action(
      id: 1,
      name: 'a',
      modelTypeId: 1,
      modelTypeName: 'Meet',
      startTime: null,
      endTime: null,
    );
    const catSame = ActionCategoryOption(
      modelTypeId: 1,
      name: 'Meet',
      dotColor: Color(0xFF000000),
    );
    expect(ActionEditViewModel.modelTypeNameIfChanged(initial, catSame), isNull);
    const catNew = ActionCategoryOption(
      modelTypeId: 1,
      name: 'Sleep',
      dotColor: Color(0xFF000000),
    );
    expect(ActionEditViewModel.modelTypeNameIfChanged(initial, catNew), 'Sleep');
  });
}
