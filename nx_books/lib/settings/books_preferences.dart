import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BooksDarkModeNotifier extends Notifier<bool> with WidgetsBindingObserver {
  static const preferenceKey = 'nx_books.appearance.dark_mode';

  var _followsSystem = true;
  var _observingSystemBrightness = false;
  var _disposed = false;

  @override
  bool build() {
    if (!_observingSystemBrightness) {
      WidgetsBinding.instance.addObserver(this);
      _observingSystemBrightness = true;
      ref.onDispose(() {
        _disposed = true;
        WidgetsBinding.instance.removeObserver(this);
      });
    }
    unawaited(_restoreSavedMode());
    return _systemPrefersDark;
  }

  @override
  void didChangePlatformBrightness() {
    if (_followsSystem) state = _systemPrefersDark;
  }

  void setDarkMode(bool value) {
    _followsSystem = false;
    state = value;
    unawaited(_persist(value));
  }

  Future<void> _restoreSavedMode() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getBool(preferenceKey);
      if (_disposed || !_followsSystem || saved == null) return;
      _followsSystem = false;
      state = saved;
    } catch (_) {
      // Keep following the system setting when preferences are unavailable.
    }
  }

  Future<void> _persist(bool value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(preferenceKey, value);
    } catch (_) {
      // The in-memory choice still applies for the current session.
    }
  }

  bool get _systemPrefersDark =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
      Brightness.dark;
}

final booksDarkModeProvider = NotifierProvider<BooksDarkModeNotifier, bool>(
  BooksDarkModeNotifier.new,
);

class BooksTextScaleNotifier extends Notifier<double> {
  static const preferenceKey = 'nx_books.reader.text_scale';
  static const defaultScale = 1.0;
  static const minimumScale = 0.7;
  static const maximumScale = 2.0;
  static const scaleStep = 0.1;

  var _changedInThisSession = false;
  var _disposed = false;

  @override
  double build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_restore());
    return defaultScale;
  }

  void increase() => _setScale(state + scaleStep);

  void decrease() => _setScale(state - scaleStep);

  void _setScale(double value) {
    _changedInThisSession = true;
    state = _normalized(value);
    unawaited(_persist(state));
  }

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getDouble(preferenceKey);
      if (_disposed || _changedInThisSession || saved == null) return;
      state = _normalized(saved);
    } catch (_) {
      // Keep the default scale when preferences are unavailable.
    }
  }

  Future<void> _persist(double value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(preferenceKey, value);
    } catch (_) {
      // The in-memory scale still applies for the current session.
    }
  }

  static double _normalized(double value) {
    final clamped = value.clamp(minimumScale, maximumScale).toDouble();
    return (clamped * 10).roundToDouble() / 10;
  }
}

final booksTextScaleProvider = NotifierProvider<BooksTextScaleNotifier, double>(
  BooksTextScaleNotifier.new,
);
