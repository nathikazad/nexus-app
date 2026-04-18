import 'package:flutter/material.dart';

import '../../app_theme.dart';

enum ActionColorTarget { sleep, work, exercise, eatCook, outdoors, routine }

extension ActionColorTargetX on ActionColorTarget {
  String get label {
    switch (this) {
      case ActionColorTarget.sleep:
        return 'Sleep';
      case ActionColorTarget.work:
        return 'Work';
      case ActionColorTarget.exercise:
        return 'Exercise';
      case ActionColorTarget.eatCook:
        return 'Eat/Cook';
      case ActionColorTarget.outdoors:
        return 'Outdoors';
      case ActionColorTarget.routine:
        return 'Routine';
    }
  }
}

class ActionColorSettings {
  ActionColorSettings._();

  static final ActionColorSettings instance = ActionColorSettings._();

  static const List<Color> palette = [
    AppColors.sleepBlue,
    AppColors.accent,
    AppColors.exerciseGreen,
    AppColors.eatYellow,
    AppColors.outdoorsTeal,
    AppColors.routineGray,
    AppColors.calPurple,
    AppColors.calGreen,
    AppColors.calOrange,
    AppColors.calBlue,
    AppColors.calOlive,
    Color(0xFFEC4899),
  ];

  final ValueNotifier<int> versionNotifier = ValueNotifier<int>(0);

  final Map<ActionColorTarget, Color> _colors = {
    ActionColorTarget.sleep: AppColors.sleepBlue,
    ActionColorTarget.work: AppColors.accent,
    ActionColorTarget.exercise: AppColors.exerciseGreen,
    ActionColorTarget.eatCook: AppColors.eatYellow,
    ActionColorTarget.outdoors: AppColors.outdoorsTeal,
    ActionColorTarget.routine: AppColors.routineGray,
  };

  Color colorFor(ActionColorTarget target) => _colors[target]!;

  void setColor(ActionColorTarget target, Color color) {
    if (_colors[target] == color) return;
    _colors[target] = color;
    versionNotifier.value++;
  }
}
