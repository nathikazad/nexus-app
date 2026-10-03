import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local calendar checkpoint, shared by all goals (not account data).
class GoalDayClock with WidgetsBindingObserver {
  GoalDayClock(this.preferences, {DateTime Function()? now})
    : now = now ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  static const preferenceKey = 'nx_cards.goal.last_local_day';
  final SharedPreferences preferences;
  final DateTime Function() now;
  final _changes = StreamController<DateTime>();
  Timer? _midnight;
  String? _day;
  Stream<DateTime> get changes => _changes.stream;

  void _check() {
    final time = now().toLocal();
    final day = '${time.year}-${time.month}-${time.day}';
    // Initialize each subscriber, then emit only on a calendar-day change.
    if (_day != day) {
      _day = day;
      _changes.add(time);
      if (preferences.getString(preferenceKey) != day) {
        unawaited(preferences.setString(preferenceKey, day));
      }
    }
    _midnight?.cancel();
    final next = DateTime(time.year, time.month, time.day + 1);
    _midnight = Timer(next.difference(time), _check);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    unawaited(_changes.close());
  }
}
