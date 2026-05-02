import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod/riverpod.dart';

enum DesktopTaskLocatorSurface { planner, sprint }

class DesktopTaskScrollRequest {
  const DesktopTaskScrollRequest({
    required this.surface,
    required this.taskId,
    required this.serial,
  });

  final DesktopTaskLocatorSurface surface;
  final int taskId;
  final int serial;
}

class DesktopTaskLocatorState {
  const DesktopTaskLocatorState({
    this.hoveredTaskId,
    this.pinnedTaskId,
    this.scrollRequest,
  });

  final int? hoveredTaskId;
  final int? pinnedTaskId;
  final DesktopTaskScrollRequest? scrollRequest;

  bool isHighlighted(int taskId) =>
      hoveredTaskId == taskId || pinnedTaskId == taskId;

  DesktopTaskLocatorState copyWith({
    int? hoveredTaskId,
    bool clearHovered = false,
    int? pinnedTaskId,
    bool clearPinned = false,
    DesktopTaskScrollRequest? scrollRequest,
  }) {
    return DesktopTaskLocatorState(
      hoveredTaskId: clearHovered
          ? null
          : (hoveredTaskId ?? this.hoveredTaskId),
      pinnedTaskId: clearPinned ? null : (pinnedTaskId ?? this.pinnedTaskId),
      scrollRequest: scrollRequest ?? this.scrollRequest,
    );
  }
}

class DesktopTaskLocator extends Notifier<DesktopTaskLocatorState> {
  Timer? _clearTimer;
  int _scrollSerial = 0;

  @override
  DesktopTaskLocatorState build() {
    ref.onDispose(() => _clearTimer?.cancel());
    return const DesktopTaskLocatorState();
  }

  void hover(int? taskId) {
    state = state.copyWith(hoveredTaskId: taskId, clearHovered: taskId == null);
  }

  void ping(int taskId) {
    _clearTimer?.cancel();
    state = state.copyWith(pinnedTaskId: taskId);
    _clearTimer = Timer(const Duration(milliseconds: 1600), () {
      state = state.copyWith(clearPinned: true);
    });
  }

  void locate({
    required DesktopTaskLocatorSurface surface,
    required int taskId,
  }) {
    _clearTimer?.cancel();
    _scrollSerial += 1;
    state = state.copyWith(
      pinnedTaskId: taskId,
      scrollRequest: DesktopTaskScrollRequest(
        surface: surface,
        taskId: taskId,
        serial: _scrollSerial,
      ),
    );
    _clearTimer = Timer(const Duration(milliseconds: 1600), () {
      state = state.copyWith(clearPinned: true);
    });
  }
}

final desktopTaskLocatorProvider =
    NotifierProvider<DesktopTaskLocator, DesktopTaskLocatorState>(
      DesktopTaskLocator.new,
      name: 'desktopTaskLocatorProvider',
    );

final Map<DesktopTaskLocatorSurface, Map<int, Set<GlobalKey>>>
_taskLocatorKeys = <DesktopTaskLocatorSurface, Map<int, Set<GlobalKey>>>{};

BuildContext? taskLocatorContextFor({
  required DesktopTaskLocatorSurface surface,
  required int taskId,
}) {
  final keysByTask = _taskLocatorKeys[surface];
  final keys = keysByTask?[taskId];
  if (keys == null) return null;
  keys.removeWhere((key) => key.currentContext == null);
  if (keys.isEmpty) {
    keysByTask?.remove(taskId);
    if (keysByTask != null && keysByTask.isEmpty) {
      _taskLocatorKeys.remove(surface);
    }
    return null;
  }
  return keys.first.currentContext;
}

void scrollLocatedTaskIntoView({
  required DesktopTaskLocatorSurface surface,
  required int taskId,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = taskLocatorContextFor(surface: surface, taskId: taskId);
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.2,
    );
  });
}

class TaskLocatorTarget extends StatefulWidget {
  const TaskLocatorTarget({
    super.key,
    required this.surface,
    required this.taskId,
    required this.child,
  });

  final DesktopTaskLocatorSurface surface;
  final int taskId;
  final Widget child;

  @override
  State<TaskLocatorTarget> createState() => _TaskLocatorTargetState();
}

class _TaskLocatorTargetState extends State<TaskLocatorTarget> {
  final GlobalKey _targetKey = GlobalKey();

  void _register() {
    _taskLocatorKeys
        .putIfAbsent(widget.surface, () => <int, Set<GlobalKey>>{})
        .putIfAbsent(widget.taskId, () => <GlobalKey>{})
        .add(_targetKey);
  }

  void _unregister(DesktopTaskLocatorSurface surface, int taskId) {
    final keysByTask = _taskLocatorKeys[surface];
    final keys = keysByTask?[taskId];
    if (keys == null) return;
    keys.remove(_targetKey);
    if (keys.isEmpty) keysByTask?.remove(taskId);
    if (keysByTask != null && keysByTask.isEmpty) {
      _taskLocatorKeys.remove(surface);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void didUpdateWidget(covariant TaskLocatorTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surface != widget.surface ||
        oldWidget.taskId != widget.taskId) {
      _unregister(oldWidget.surface, oldWidget.taskId);
      _register();
    }
  }

  @override
  void dispose() {
    _unregister(widget.surface, widget.taskId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(key: _targetKey, child: widget.child);
  }
}
