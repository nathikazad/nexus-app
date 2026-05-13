import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';

import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nexus_voice_assistant/domain/battery/battery_point.dart';
import 'package:nexus_voice_assistant/domain/battery/battery_repository.dart';

const Object _batteryCopyUnset = Object();

class BatteryViewState {
  const BatteryViewState({
    required this.loading,
    this.error,
    required this.available,
    required this.selected,
    required this.loadingDay,
    required this.points,
    this.transientNotice,
  });

  final bool loading;
  final String? error;
  final Set<DateTime> available;
  final DateTime selected;
  final bool loadingDay;
  final List<BatteryPoint> points;

  final String? transientNotice;

  factory BatteryViewState.initial(DateTime today) {
    return BatteryViewState(
      loading: true,
      available: {},
      selected: today,
      loadingDay: false,
      points: const [],
    );
  }

  BatteryViewState copyWith({
    bool? loading,
    Object? error = _batteryCopyUnset,
    Set<DateTime>? available,
    DateTime? selected,
    bool? loadingDay,
    List<BatteryPoint>? points,
    Object? transientNotice = _batteryCopyUnset,
    bool clearTransientNotice = false,
  }) {
    return BatteryViewState(
      loading: loading ?? this.loading,
      error:
          identical(error, _batteryCopyUnset) ? this.error : error as String?,
      available: available ?? this.available,
      selected: selected ?? this.selected,
      loadingDay: loadingDay ?? this.loadingDay,
      points: points ?? this.points,
      transientNotice: clearTransientNotice
          ? null
          : (identical(transientNotice, _batteryCopyUnset)
              ? this.transientNotice
              : transientNotice as String?),
    );
  }
}

class BatteryViewNotifier extends Notifier<BatteryViewState> {
  Timer? _pollTimer;

  BatteryRepository get _repo => ref.read(batteryRepositoryProvider);

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  @override
  BatteryViewState build() {
    ref.onDispose(_stopPolling);
    final now = DateTime.now();
    return BatteryViewState.initial(
      DateTime(now.year, now.month, now.day),
    );
  }

  void clearTransientNotice() {
    if (state.transientNotice != null) {
      state = state.copyWith(clearTransientNotice: true);
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startPolling() {
    _stopPolling();
    if (!_isToday(state.selected)) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(_pollForNewPoints());
    });
  }

  Future<void> _pollForNewPoints() async {
    if (!_isToday(state.selected)) return;
    final base = ref.read(imageBaseUrlProvider);
    final uid = ref.read(userIdProvider);
    if (base == null || uid == null || uid.isEmpty) return;
    try {
      final fresh = await _repo.fetchBatteryDay(base, uid, state.selected);
      if (fresh.length > state.points.length) {
        state = state.copyWith(points: fresh);
      }
    } catch (_) {}
  }

  Future<void> loadDates() async {
    final base = ref.read(imageBaseUrlProvider);
    final uid = ref.read(userIdProvider);
    if (base == null || uid == null || uid.isEmpty) {
      state = state.copyWith(
        loading: false,
        error: 'Not logged in or missing image server URL.',
      );
      return;
    }

    state = state.copyWith(loading: true, error: null);

    try {
      final dates = await _repo.fetchBatteryDates(base, uid);
      final initial = _initialSelected(dates);
      state = state.copyWith(
        available: dates.toSet(),
        selected: initial,
        loading: false,
      );
      await loadDay();
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        loading: false,
      );
    }
  }

  DateTime _initialSelected(List<DateTime> dates) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (dates.contains(today)) return today;
    if (dates.isNotEmpty) return dates.first;
    return today;
  }

  Future<void> loadDay() async {
    final base = ref.read(imageBaseUrlProvider);
    final uid = ref.read(userIdProvider);
    if (base == null || uid == null || uid.isEmpty) return;

    state = state.copyWith(loadingDay: true, points: []);

    try {
      final pts = await _repo.fetchBatteryDay(base, uid, state.selected);
      state = state.copyWith(
        points: pts,
        loadingDay: false,
      );
      _startPolling();
    } catch (e) {
      _stopPolling();
      state = state.copyWith(
        points: [],
        loadingDay: false,
        transientNotice: 'Failed to load battery data: $e',
      );
    }
  }

  Future<void> applyPickedDate(DateTime picked) async {
    state = state.copyWith(
      selected: DateTime(picked.year, picked.month, picked.day),
    );
    await loadDay();
  }
}

final batteryViewModelProvider =
    NotifierProvider.autoDispose<BatteryViewNotifier, BatteryViewState>(
  BatteryViewNotifier.new,
);
