import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class GpsSample {
  const GpsSample({
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.altitudeM,
    required this.altitudeAccuracyM,
    required this.headingDeg,
    required this.headingAccuracyDeg,
    required this.speedMps,
    required this.speedAccuracyMps,
    required this.isMocked,
    this.floor,
  });

  final DateTime time;
  final double latitude;
  final double longitude;
  final double accuracyM;
  final double altitudeM;
  final double altitudeAccuracyM;
  final double headingDeg;
  final double headingAccuracyDeg;
  final double speedMps;
  final double speedAccuracyMps;
  final bool isMocked;
  final int? floor;

  GpsSample copyWith({DateTime? time}) {
    return GpsSample(
      time: time ?? this.time,
      latitude: latitude,
      longitude: longitude,
      accuracyM: accuracyM,
      altitudeM: altitudeM,
      altitudeAccuracyM: altitudeAccuracyM,
      headingDeg: headingDeg,
      headingAccuracyDeg: headingAccuracyDeg,
      speedMps: speedMps,
      speedAccuracyMps: speedAccuracyMps,
      isMocked: isMocked,
      floor: floor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time.toLocal().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_m': accuracyM,
      'altitude_m': altitudeM,
      'altitude_accuracy_m': altitudeAccuracyM,
      'heading_deg': headingDeg,
      'heading_accuracy_deg': headingAccuracyDeg,
      'speed_mps': speedMps,
      'speed_accuracy_mps': speedAccuracyMps,
      'is_mocked': isMocked,
      if (floor != null) 'floor': floor,
    };
  }

  static GpsSample fromPosition(Position position) {
    return GpsSample(
      time: position.timestamp,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyM: position.accuracy,
      altitudeM: position.altitude,
      altitudeAccuracyM: position.altitudeAccuracy,
      headingDeg: position.heading,
      headingAccuracyDeg: position.headingAccuracy,
      speedMps: position.speed,
      speedAccuracyMps: position.speedAccuracy,
      floor: position.floor,
      isMocked: position.isMocked,
    );
  }
}

typedef GpsSampleReader = Future<GpsSample?> Function();
typedef GpsSampleStreamFactory = Stream<GpsSample> Function();

class GpsUploadManager {
  GpsUploadManager({
    required this.httpBaseUrl,
    required this.headers,
    http.Client? client,
    GpsSampleReader? sampleReader,
    GpsSampleStreamFactory? sampleStreamFactory,
    this.sampleInterval = const Duration(seconds: 60),
    this.flushInterval = const Duration(seconds: 600),
    this.source = 'phone',
    this.timezoneLabel,
  })  : _client = client ?? http.Client(),
        _sampleReader = sampleReader ?? _readCurrentSample,
        _sampleStreamFactory = sampleStreamFactory ?? _positionSampleStream;

  final String httpBaseUrl;
  final Map<String, String> headers;
  final http.Client _client;
  final GpsSampleReader _sampleReader;
  final GpsSampleStreamFactory _sampleStreamFactory;
  final Duration sampleInterval;
  final Duration flushInterval;
  final String source;
  final String? timezoneLabel;

  final List<GpsSample> _pending = [];
  Timer? _sampleTimer;
  Timer? _flushTimer;
  StreamSubscription<GpsSample>? _positionSubscription;
  GpsSample? _latestSample;
  bool _isCollecting = false;
  bool _isFlushing = false;

  int get pendingCount => _pending.length;
  bool get isRunning =>
      _positionSubscription != null ||
      _sampleTimer != null ||
      _flushTimer != null;

  void start() {
    if (isRunning) return;
    debugPrint(
      '[GPS Upload] starting stream sampleInterval=${sampleInterval.inSeconds}s '
      'flushInterval=${flushInterval.inSeconds}s',
    );
    _positionSubscription = _sampleStreamFactory().listen(
      (sample) {
        _latestSample = sample;
        if (_pending.isEmpty) {
          _recordLatestSample(reason: 'stream-start');
        } else {
          // debugPrint(
          //   '[GPS Upload] stream update '
          //   'time=${sample.time.toLocal().toIso8601String()} '
          //   'lat=${sample.latitude.toStringAsFixed(6)} '
          //   'lon=${sample.longitude.toStringAsFixed(6)} '
          //   'accuracy_m=${sample.accuracyM.toStringAsFixed(1)}',
          // );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[GPS Upload] stream failed: $error');
      },
      cancelOnError: false,
    );
    _sampleTimer = Timer.periodic(sampleInterval, (_) {
      _recordLatestSample(reason: 'interval');
    });
    _flushTimer = Timer.periodic(flushInterval, (_) {
      debugPrint(
        '[GPS Upload] flush tick pending=${_pending.length} '
        'isFlushing=$_isFlushing',
      );
      unawaited(flush());
    });
  }

  Future<void> stop({bool flushPending = true}) async {
    debugPrint(
      '[GPS Upload] stopping pending=${_pending.length} '
      'flushPending=$flushPending',
    );
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (flushPending) {
      await flush();
    }
  }

  void _recordLatestSample({required String reason}) {
    final sample = _latestSample;
    if (sample == null) {
      debugPrint('[GPS Upload] sample skipped: no streamed position yet');
      return;
    }
    final timestamped = sample.copyWith(time: DateTime.now());
    _pending.add(timestamped);
    debugPrint(
      '[GPS Upload] sampled reason=$reason '
      'time=${timestamped.time.toLocal().toIso8601String()} '
      'lat=${timestamped.latitude.toStringAsFixed(6)} '
      'lon=${timestamped.longitude.toStringAsFixed(6)} '
      'accuracy_m=${timestamped.accuracyM.toStringAsFixed(1)} '
      'pending=${_pending.length}',
    );
  }

  Future<void> collectOnce() async {
    if (_isCollecting) return;
    _isCollecting = true;
    try {
      final sample = await _sampleReader();
      if (sample != null) {
        _pending.add(sample);
        debugPrint(
          '[GPS Upload] sampled '
          'time=${sample.time.toLocal().toIso8601String()} '
          'lat=${sample.latitude.toStringAsFixed(6)} '
          'lon=${sample.longitude.toStringAsFixed(6)} '
          'accuracy_m=${sample.accuracyM.toStringAsFixed(1)} '
          'pending=${_pending.length}',
        );
      } else {
        debugPrint('[GPS Upload] no sample available');
      }
    } catch (e) {
      debugPrint('[GPS Upload] sample failed: $e');
    } finally {
      _isCollecting = false;
    }
  }

  Future<bool> flush() async {
    if (_isFlushing) {
      debugPrint('[GPS Upload] flush skipped: already flushing');
      return true;
    }
    if (_pending.isEmpty) {
      debugPrint('[GPS Upload] flush skipped: no pending samples');
      return true;
    }
    _isFlushing = true;
    final batch = List<GpsSample>.from(_pending);
    try {
      debugPrint('[GPS Upload] flushing ${batch.length} samples');
      final base = httpBaseUrl.replaceAll(RegExp(r'/+$'), '');
      final response = await _client
          .post(
            Uri.parse('$base/gps/upload'),
            headers: {
              ...headers,
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'source': source,
              if (timezoneLabel != null) 'timezone': timezoneLabel,
              'samples': [for (final sample in batch) sample.toJson()],
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[GPS Upload] server rejected ${batch.length} samples: '
          '${response.statusCode} ${response.body}',
        );
        return false;
      }
      final decoded = jsonDecode(response.body);
      final ok = decoded is Map && decoded['ok'] == true;
      if (ok) {
        _pending.removeRange(0, batch.length);
      }
      debugPrint('[GPS Upload] uploaded ${batch.length} samples ok=$ok');
      return ok;
    } catch (e) {
      debugPrint('[GPS Upload] upload failed for ${batch.length} samples: $e');
      return false;
    } finally {
      _isFlushing = false;
    }
  }

  static Future<GpsSample?> _readCurrentSample() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      ),
    );
    return GpsSample.fromPosition(position);
  }

  static Stream<GpsSample> _positionSampleStream() async* {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[GPS Upload] stream unavailable: location services disabled');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('[GPS Upload] stream unavailable: permission=$permission');
      return;
    }

    yield* Geolocator.getPositionStream(
      locationSettings: _streamLocationSettings(),
    ).map(GpsSample.fromPosition);
  }

  static LocationSettings _streamLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        activityType: ActivityType.other,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: false,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Nexus GPS active',
          notificationText: 'Nexus is collecting GPS timeline points.',
          enableWakeLock: true,
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }
}

String localTimezoneOffsetLabel([DateTime? now]) {
  final offset = (now ?? DateTime.now()).timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final hours = abs.inHours.toString().padLeft(2, '0');
  final minutes = (abs.inMinutes % 60).toString().padLeft(2, '0');
  return 'UTC$sign$hours:$minutes';
}
