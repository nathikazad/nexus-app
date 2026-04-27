import 'package:riverpod/riverpod.dart';

import 'package:nx_projects/domain/task/task_status.dart';

/// User-selected [TaskKind] **names** (`feat`, `bug`, `task`). Empty = no filter (all kinds).
class FilterKindSet extends Notifier<Set<String>> {
  static const Set<String> allKindKeys = {'feat', 'bug', 'task'};

  @override
  Set<String> build() => const {};

  void toggle(String name) {
    if (!allKindKeys.contains(name)) return;
    final next = {...state};
    if (next.contains(name)) {
      next.remove(name);
    } else {
      next.add(name);
    }
    state = next;
  }

  void clear() => state = const {};

  void setAll() => state = {...allKindKeys};

  // Mobile single-select filter sheet: matches prior `all` / `feat` / `bug` behavior.
  void setMobileKind(String v) {
    state = switch (v) {
      'all' => const <String>{},
      'feat' => const {'feat'},
      'bug' => const {'bug'},
      _ => const <String>{},
    };
  }
}

final filterKindSetProvider = NotifierProvider<FilterKindSet, Set<String>>(
  FilterKindSet.new,
);

/// User-selected [TaskStatus] **names** (`todo`, `doing`, `done`, `blocked`). Empty = no filter.
class FilterStatusSet extends Notifier<Set<String>> {
  static const Set<String> allStatusKeys = {
    'todo',
    'doing',
    'done',
    'blocked',
  };

  @override
  Set<String> build() => const {};

  void toggle(String name) {
    if (!allStatusKeys.contains(name)) return;
    final next = {...state};
    if (next.contains(name)) {
      next.remove(name);
    } else {
      next.add(name);
    }
    state = next;
  }

  void clear() => state = const {};

  void setAll() => state = {...allStatusKeys};

  /// Mobile filter sheet: `all`, `open` (not done), `done`.
  void setMobileStatus(String v) {
    state = switch (v) {
      'all' => const <String>{},
      'open' => {
          TaskStatus.todo.name,
          TaskStatus.doing.name,
          TaskStatus.blocked.name,
        },
      'done' => {TaskStatus.done.name},
      _ => const <String>{},
    };
  }
}

final filterStatusSetProvider = NotifierProvider<FilterStatusSet, Set<String>>(
  FilterStatusSet.new,
);

class FilterProjectIds extends Notifier<Set<int>> {
  @override
  Set<int> build() => const <int>{};

  void toggle(int id) {
    final next = {...state};
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = next;
  }

  void setAll(Iterable<int> ids) => state = ids.toSet();

  void clear() => state = const <int>{};
}

final filterProjectIdsProvider = NotifierProvider<FilterProjectIds, Set<int>>(
  FilterProjectIds.new,
);

class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String v) => state = v;
}

final searchQueryProvider = NotifierProvider<SearchQuery, String>(
  SearchQuery.new,
);
