import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';

import 'package:nexus_voice_assistant/data/image_exports.dart';
import 'package:nexus_voice_assistant/data/providers.dart';

const Object _imagesCopyUnset = Object();

class ImagesViewState {
  const ImagesViewState({
    required this.loading,
    this.error,
    required this.available,
    required this.selected,
    required this.loadingDay,
    required this.dayEntries,
    required this.sliderValue,
    required this.minTime,
    required this.maxTime,
    this.transientNotice,
  });

  final bool loading;
  final String? error;
  final Set<DateTime> available;
  final DateTime selected;
  final bool loadingDay;
  final List<ImageEntry> dayEntries;
  final double sliderValue;
  final double minTime;
  final double maxTime;

  /// One-shot UI message (e.g. snackbar); cleared by [ImagesViewNotifier.clearTransientNotice].
  final String? transientNotice;

  factory ImagesViewState.initial(DateTime today) {
    return ImagesViewState(
      loading: true,
      available: {},
      selected: today,
      loadingDay: false,
      dayEntries: const [],
      sliderValue: 0,
      minTime: 0,
      maxTime: 1439,
    );
  }

  ImagesViewState copyWith({
    bool? loading,
    Object? error = _imagesCopyUnset,
    Set<DateTime>? available,
    DateTime? selected,
    bool? loadingDay,
    List<ImageEntry>? dayEntries,
    double? sliderValue,
    double? minTime,
    double? maxTime,
    Object? transientNotice = _imagesCopyUnset,
    bool clearTransientNotice = false,
  }) {
    return ImagesViewState(
      loading: loading ?? this.loading,
      error: identical(error, _imagesCopyUnset) ? this.error : error as String?,
      available: available ?? this.available,
      selected: selected ?? this.selected,
      loadingDay: loadingDay ?? this.loadingDay,
      dayEntries: dayEntries ?? this.dayEntries,
      sliderValue: sliderValue ?? this.sliderValue,
      minTime: minTime ?? this.minTime,
      maxTime: maxTime ?? this.maxTime,
      transientNotice: clearTransientNotice
          ? null
          : (identical(transientNotice, _imagesCopyUnset)
              ? this.transientNotice
              : transientNotice as String?),
    );
  }
}

int imagesCurrentIndex(ImagesViewState s) {
  var idx = -1;
  for (var i = 0; i < s.dayEntries.length; i++) {
    if (s.dayEntries[i].minutesSinceMidnight <= s.sliderValue) {
      idx = i;
    } else {
      break;
    }
  }
  return idx;
}

ImageEntry? imagesEntryForSlider(ImagesViewState s, double v) {
  ImageEntry? best;
  for (final e in s.dayEntries) {
    if (e.minutesSinceMidnight <= v) {
      best = e;
    } else {
      break;
    }
  }
  return best;
}

class ImagesViewNotifier extends Notifier<ImagesViewState> {
  ImagesViewNotifier(this._source);

  final String _source;

  Timer? _pollTimer;

  ImageRepository get _repo => ref.read(imageRepositoryProvider);

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  @override
  ImagesViewState build() {
    ref.onDispose(_stopPolling);
    final now = DateTime.now();
    return ImagesViewState.initial(
      DateTime(now.year, now.month, now.day),
    );
  }

  void clearTransientNotice() {
    if (state.transientNotice != null) {
      state = state.copyWith(clearTransientNotice: true);
    }
  }

  void setSlider(double v) {
    state = state.copyWith(sliderValue: v);
  }

  void stepPrev() {
    final i = imagesCurrentIndex(state);
    if (i <= 0) return;
    state = state.copyWith(
      sliderValue: state.dayEntries[i - 1].minutesSinceMidnight,
    );
  }

  void stepNext() {
    final i = imagesCurrentIndex(state);
    if (i < 0 || i >= state.dayEntries.length - 1) return;
    state = state.copyWith(
      sliderValue: state.dayEntries[i + 1].minutesSinceMidnight,
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startPolling() {
    _stopPolling();
    if (!_isToday(state.selected)) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_pollForNewImages());
    });
  }

  Future<void> _pollForNewImages() async {
    if (!_isToday(state.selected)) return;
    final base = ref.read(imageBaseUrlProvider);
    final uid = ref.read(userIdProvider);
    if (base == null || uid == null || uid.isEmpty) return;

    try {
      final fresh = await _repo.fetchImagesForDay(
        base,
        uid,
        _source,
        state.selected,
      );
      final existing = state.dayEntries.map((e) => e.filename).toSet();
      final newOnes =
          fresh.where((e) => !existing.contains(e.filename)).toList();
      if (newOnes.isEmpty) return;

      final merged = [...state.dayEntries, ...newOnes]..sort((a, b) {
          final c = a.minutesSinceMidnight.compareTo(b.minutesSinceMidnight);
          if (c != 0) return c;
          return a.filename.compareTo(b.filename);
        });

      final mins = merged.map((e) => e.minutesSinceMidnight).toList();
      final minT = mins.reduce((a, b) => a < b ? a : b);
      final maxT = mins.reduce((a, b) => a > b ? a : b);

      state = state.copyWith(
        dayEntries: merged,
        minTime: minT,
        maxTime: maxT,
      );
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
      final dates = await _repo.fetchAvailableDates(base, uid, _source);
      final initial = _initialSelected(dates);
      state = state.copyWith(
        available: dates.toSet(),
        selected: initial,
        loading: false,
      );
      await loadImagesForSelectedDay();
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

  Future<void> loadImagesForSelectedDay() async {
    final base = ref.read(imageBaseUrlProvider);
    final uid = ref.read(userIdProvider);
    if (base == null || uid == null || uid.isEmpty) return;

    _stopPolling();

    state = state.copyWith(loadingDay: true, dayEntries: []);

    try {
      final entries = await _repo.fetchImagesForDay(
        base,
        uid,
        _source,
        state.selected,
      );
      if (entries.isEmpty) {
        state = state.copyWith(
          dayEntries: [],
          minTime: 0,
          maxTime: 1439,
          sliderValue: 0,
          loadingDay: false,
        );
        _startPolling();
        return;
      }
      final mins = entries.map((e) => e.minutesSinceMidnight).toList();
      final minT = mins.reduce((a, b) => a < b ? a : b);
      final maxT = mins.reduce((a, b) => a > b ? a : b);
      state = state.copyWith(
        dayEntries: entries,
        minTime: minT,
        maxTime: maxT,
        sliderValue: minT,
        loadingDay: false,
      );
      _startPolling();
    } catch (e) {
      _stopPolling();
      state = state.copyWith(
        dayEntries: [],
        loadingDay: false,
        transientNotice: 'Failed to load images: $e',
      );
    }
  }

  Future<void> applyPickedDate(DateTime picked) async {
    state = state.copyWith(
      selected: DateTime(picked.year, picked.month, picked.day),
    );
    await loadImagesForSelectedDay();
  }
}

final imagesViewModelProvider = NotifierProvider.autoDispose
    .family<ImagesViewNotifier, ImagesViewState, String>(
        ImagesViewNotifier.new);
