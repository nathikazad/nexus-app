import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/data/fake/seed_data.dart';
import 'package:riverpod/riverpod.dart';

/// Bottom tab index: 0 Projects, 1 Priority, 2 Sprint, 3 Daily
class MainTabIndex extends Notifier<int> {
  @override
  int build() => 1;

  void setTab(int v) => state = v;
}

final mainTabIndexProvider = NotifierProvider<MainTabIndex, int>(MainTabIndex.new);

class SelectedProjectId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? v) => state = v;
}

final selectedProjectIdProvider = NotifierProvider<SelectedProjectId, String?>(SelectedProjectId.new);

class SelectedSubProjectId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? v) => state = v;
}

final selectedSubProjectIdProvider =
    NotifierProvider<SelectedSubProjectId, String?>(SelectedSubProjectId.new);

class SelectedPriorityBucket extends Notifier<TaskBucket?> {
  @override
  TaskBucket? build() => null;

  void set(TaskBucket? v) => state = v;
}

final selectedPriorityBucketProvider =
    NotifierProvider<SelectedPriorityBucket, TaskBucket?>(SelectedPriorityBucket.new);

class SprintIndex extends Notifier<int> {
  @override
  int build() => 1;

  void set(int v) => state = v;
}

final sprintIndexProvider = NotifierProvider<SprintIndex, int>(SprintIndex.new);

class DailyDate extends Notifier<String> {
  @override
  String build() => kReferenceTodayYmd;

  void set(String v) => state = v;
}

final dailyDateProvider = NotifierProvider<DailyDate, String>(DailyDate.new);

/// Desktop top-level view: 0 = Planner, 1 = Sprint, 2 = Today (see `reference/desktop/`).
class DesktopViewIndex extends Notifier<int> {
  @override
  int build() => 0;

  void setView(int v) => state = v;
}

final desktopViewIndexProvider = NotifierProvider<DesktopViewIndex, int>(DesktopViewIndex.new);

/// Planner left pane: 0 = Priority, 1 = Projects (Priority / Projects toggle).
class DesktopPlannerMode extends Notifier<int> {
  @override
  int build() => 0;

  void setMode(int v) => state = v;
}

final desktopPlannerModeProvider = NotifierProvider<DesktopPlannerMode, int>(DesktopPlannerMode.new);
