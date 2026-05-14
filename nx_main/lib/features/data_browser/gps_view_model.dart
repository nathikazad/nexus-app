import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';

import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nexus_voice_assistant/domain/gps/gps_point.dart';
import 'package:nexus_voice_assistant/domain/gps/gps_repository.dart';

const Object _gpsCopyUnset = Object();

class GpsViewState {
  const GpsViewState({
    required this.loading,
    this.error,
    required this.available,
    required this.selected,
    required this.loadingDay,
    required this.points,
    required this.selectedIndex,
    this.transientNotice,
  });

  final bool loading;
  final String? error;
  final Set<DateTime> available;
  final DateTime selected;
  final bool loadingDay;
  final List<GpsPoint> points;
  final int selectedIndex;
  final String? transientNotice;

  factory GpsViewState.initial(DateTime today) {
    return GpsViewState(
      loading: true,
      available: {},
      selected: today,
      loadingDay: false,
      points: const [],
      selectedIndex: 0,
    );
  }

  GpsViewState copyWith({
    bool? loading,
    Object? error = _gpsCopyUnset,
    Set<DateTime>? available,
    DateTime? selected,
    bool? loadingDay,
    List<GpsPoint>? points,
    int? selectedIndex,
    Object? transientNotice = _gpsCopyUnset,
    bool clearTransientNotice = false,
  }) {
    return GpsViewState(
      loading: loading ?? this.loading,
      error: identical(error, _gpsCopyUnset) ? this.error : error as String?,
      available: available ?? this.available,
      selected: selected ?? this.selected,
      loadingDay: loadingDay ?? this.loadingDay,
      points: points ?? this.points,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      transientNotice: clearTransientNotice
          ? null
          : (identical(transientNotice, _gpsCopyUnset)
              ? this.transientNotice
              : transientNotice as String?),
    );
  }
}

class GpsViewNotifier extends Notifier<GpsViewState> {
  GpsRepository get _repo => ref.read(gpsRepositoryProvider);

  @override
  GpsViewState build() {
    final now = DateTime.now();
    return GpsViewState.initial(DateTime(now.year, now.month, now.day));
  }

  void clearTransientNotice() {
    if (state.transientNotice != null) {
      state = state.copyWith(clearTransientNotice: true);
    }
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
      final dates = await _repo.fetchGpsDates(base, uid);
      final initial = _initialSelected(dates);
      state = state.copyWith(
        available: dates.toSet(),
        selected: initial,
        loading: false,
      );
      await loadDay();
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }

  DateTime _initialSelected(List<DateTime> dates) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (dates.contains(today)) return today;
    if (dates.isNotEmpty) return dates.last;
    return today;
  }

  Future<void> loadDay() async {
    final base = ref.read(imageBaseUrlProvider);
    final uid = ref.read(userIdProvider);
    if (base == null || uid == null || uid.isEmpty) return;

    state = state.copyWith(loadingDay: true, points: [], selectedIndex: 0);
    try {
      final points = await _repo.fetchGpsDay(base, uid, state.selected);
      state = state.copyWith(
        points: points,
        loadingDay: false,
        selectedIndex: points.isEmpty ? 0 : points.length - 1,
      );
    } catch (e) {
      state = state.copyWith(
        points: [],
        loadingDay: false,
        selectedIndex: 0,
        transientNotice: 'Failed to load GPS data: $e',
      );
    }
  }

  Future<void> applyPickedDate(DateTime picked) async {
    state = state.copyWith(
      selected: DateTime(picked.year, picked.month, picked.day),
    );
    await loadDay();
  }

  void setSelectedIndex(int index) {
    if (state.points.isEmpty) return;
    state = state.copyWith(
      selectedIndex: index.clamp(0, state.points.length - 1),
    );
  }
}

final gpsViewModelProvider =
    NotifierProvider.autoDispose<GpsViewNotifier, GpsViewState>(
  GpsViewNotifier.new,
);
