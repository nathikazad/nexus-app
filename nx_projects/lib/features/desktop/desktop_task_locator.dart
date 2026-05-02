import 'dart:async';

import 'package:riverpod/riverpod.dart';

enum DesktopTaskLocatorSurface { planner, sprint }

enum DesktopTaskLocateSource { sprintCart }

class DesktopTaskLocateEffect {
  const DesktopTaskLocateEffect({
    required this.source,
    required this.surface,
    required this.taskId,
    required this.serial,
  });

  final DesktopTaskLocateSource source;
  final DesktopTaskLocatorSurface surface;
  final int taskId;
  final int serial;
  bool get isOneShot => true;
}

class DesktopTaskLocatorState {
  const DesktopTaskLocatorState({
    this.hoveredTaskId,
    this.pinnedTaskId,
    this.locateEffect,
  });

  final int? hoveredTaskId;
  final int? pinnedTaskId;
  final DesktopTaskLocateEffect? locateEffect;

  bool isHighlighted(int taskId) =>
      hoveredTaskId == taskId || pinnedTaskId == taskId;

  DesktopTaskLocatorState copyWith({
    int? hoveredTaskId,
    bool clearHovered = false,
    int? pinnedTaskId,
    bool clearPinned = false,
    DesktopTaskLocateEffect? locateEffect,
  }) {
    return DesktopTaskLocatorState(
      hoveredTaskId: clearHovered
          ? null
          : (hoveredTaskId ?? this.hoveredTaskId),
      pinnedTaskId: clearPinned ? null : (pinnedTaskId ?? this.pinnedTaskId),
      locateEffect: locateEffect ?? this.locateEffect,
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
    required DesktopTaskLocateSource source,
    required DesktopTaskLocatorSurface surface,
    required int taskId,
  }) {
    _clearTimer?.cancel();
    _scrollSerial += 1;
    state = state.copyWith(
      pinnedTaskId: taskId,
      locateEffect: DesktopTaskLocateEffect(
        source: source,
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
