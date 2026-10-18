import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A bounded, content-free trace of the most recent launch, for device diagnosis.
abstract final class StartupTiming {
  static Stopwatch? _clock;
  static final Map<String, int> _marks = {};
  static int _started = 0;
  static Future<void> _writing = Future.value();
  static void begin() {
    _clock = Stopwatch()..start();
    _started = DateTime.now().millisecondsSinceEpoch;
    _marks.clear();
    mark('dart_main');
  }

  static void mark(String event) {
    if (_clock == null || _marks.containsKey(event)) return;
    _marks[event] = _clock!.elapsedMilliseconds;
    final body = jsonEncode({
      'started_ms': _started,
      'marks_ms': {..._marks},
    });
    _writing = _writing
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('nx_startup_timing', body);
        })
        .catchError((Object _) {});
    unawaited(_writing);
  }
}
