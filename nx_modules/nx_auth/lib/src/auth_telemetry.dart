import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_presets.dart';

/// Durable, best-effort authentication lifecycle diagnostics.
///
/// Rows contain timing and outcome metadata only. Access, refresh, and ID token
/// values are never stored or uploaded. Events remain queued when the current
/// credential cannot authenticate the upload and are retried after the same
/// app/user signs in again.
final class AuthTelemetryRecorder {
  AuthTelemetryRecorder({http.Client? client}) : _client = client;

  static const _maximumQueuedEvents = 100;
  final http.Client? _client;
  Future<void> _writes = Future.value();

  Future<void> beginSession({
    required String app,
    required String userId,
    required bool interactive,
    required Map<String, Object?> token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();
    final id = interactive
        ? _newSessionId(now)
        : prefs.getString(_sessionIdKey(app, userId)) ?? _newSessionId(now);
    final startedAt = interactive
        ? now
        : DateTime.tryParse(
                prefs.getString(_sessionStartedKey(app, userId)) ?? '',
              ) ??
              now;
    await prefs.setString(_sessionIdKey(app, userId), id);
    await prefs.setString(
      _sessionStartedKey(app, userId),
      startedAt.toIso8601String(),
    );
    await enqueue(
      app: app,
      userId: userId,
      event: interactive ? 'sign_in_succeeded' : 'session_restored',
      fields: token,
      at: now,
    );
  }

  Future<void> enqueue({
    required String app,
    required String userId,
    required String event,
    Map<String, Object?> fields = const {},
    DateTime? at,
  }) {
    final operation = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final now = (at ?? DateTime.now()).toUtc();
      final startedAt = DateTime.tryParse(
        prefs.getString(_sessionStartedKey(app, userId)) ?? '',
      );
      final rows = _readQueue(prefs, app, userId)
        ..add(<String, Object?>{
          'time': now.toIso8601String(),
          'origin_kind': 'app',
          'origin': app,
          'severity': event.endsWith('failed') || event == 'session_rejected'
              ? 'warning'
              : 'info',
          'event_name': 'auth.$event',
          'category': 'auth',
          'message': 'Authentication: ${event.replaceAll('_', ' ')}',
          'session_id': prefs.getString(_sessionIdKey(app, userId)),
          'payload': <String, Object?>{
            'app': app,
            'user_id': userId,
            if (startedAt != null)
              'session_age_seconds': now.difference(startedAt).inSeconds,
            ...fields,
          },
        });
      if (rows.length > _maximumQueuedEvents) {
        rows.removeRange(0, rows.length - _maximumQueuedEvents);
      }
      await prefs.setString(_queueKey(app, userId), jsonEncode(rows));
    });
    _writes = operation.catchError((_) {});
    return operation;
  }

  Future<void> endSession({
    required String app,
    required String userId,
    required String event,
    Map<String, Object?> fields = const {},
  }) async {
    await enqueue(app: app, userId: userId, event: event, fields: fields);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionIdKey(app, userId));
    await prefs.remove(_sessionStartedKey(app, userId));
  }

  Future<void> flush({
    required BackendPreset preset,
    required String app,
    required String userId,
    required String accessToken,
  }) async {
    await _writes;
    if (!preset.requiresOidc || accessToken.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final rows = _readQueue(prefs, app, userId);
    if (rows.isEmpty) return;
    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    try {
      final response = await client
          .post(
            Uri.parse('${resolve(preset).imageHttp}/logs/auth/upload'),
            headers: {
              'authorization': 'Bearer $accessToken',
              'content-type': 'application/json',
            },
            body: jsonEncode({'rows': rows}),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final cleanup = _writes.then((_) async {
          final current = _readQueue(prefs, app, userId);
          if (current.length < rows.length ||
              jsonEncode(current.take(rows.length).toList()) !=
                  jsonEncode(rows)) {
            return;
          }
          current.removeRange(0, rows.length);
          if (current.isEmpty) {
            await prefs.remove(_queueKey(app, userId));
          } else {
            await prefs.setString(_queueKey(app, userId), jsonEncode(current));
          }
        });
        _writes = cleanup.catchError((_) {});
        await cleanup;
      }
    } catch (_) {
      // Authentication must never fail because diagnostics are unavailable.
    } finally {
      if (ownsClient) client.close();
    }
  }

  List<Map<String, dynamic>> _readQueue(
    SharedPreferences prefs,
    String app,
    String userId,
  ) {
    final encoded = prefs.getString(_queueKey(app, userId));
    if (encoded == null) return [];
    try {
      return (jsonDecode(encoded) as List<dynamic>)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _newSessionId(DateTime now) =>
      '${now.microsecondsSinceEpoch.toRadixString(36)}-${Random.secure().nextInt(1 << 32).toRadixString(36)}';

  String _queueKey(String app, String userId) =>
      'nexus.auth.telemetry.queue.$app.$userId';
  String _sessionIdKey(String app, String userId) =>
      'nexus.auth.telemetry.session.$app.$userId.id';
  String _sessionStartedKey(String app, String userId) =>
      'nexus.auth.telemetry.session.$app.$userId.started';
}

final authTelemetryRecorder = AuthTelemetryRecorder();
