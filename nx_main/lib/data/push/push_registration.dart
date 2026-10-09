import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import '../providers.dart';
import '../../domain/ble/ble_connection_state.dart';
import 'push_haptics.dart';

final pushRegistrationProvider = Provider<void>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
  final user = ref.watch(authProvider).value;
  final client = ref.watch(nexusHttpClientProvider);
  if (user == null || !user.preset.requiresOidc || client == null) return;
  final session = PushRegistrationSession(
    client: client,
    endpoint: Uri.parse('${resolve(user.preset).imageHttp}/v1/push/register'),
    haptics: PushHaptics(
        userId: user.userId.toString(),
        pulse: () async {
          final service = ref.read(bleBackgroundServiceProvider);
          if (service.lastKnownBleStatus != BleConnectionState.connected)
            return false;
          return service.writeHaptic(16);
        }),
  );
  PushRegistrationSession.current = session;
  PushRegistrationSession.channel.setMethodCallHandler((call) async {
    final active = PushRegistrationSession.current;
    if (call.method != 'notification' || active == null || active._disposed)
      return false;
    return await active.haptics?.receive(call.arguments) ?? false;
  });
  ref.onDispose(session.dispose);
  unawaited(session.refresh());
});

class PushRegistrationSession {
  PushRegistrationSession(
      {required this.client, required this.endpoint, this.haptics});
  final PushHaptics? haptics;
  static PushRegistrationSession? current;
  static const channel = MethodChannel('com.nexus/push');
  final NexusAuthenticatedClient client;
  final Uri endpoint;
  Map<String, dynamic>? _registration;
  Timer? _retry;
  bool _disposed = false;
  Future<void>? _pending;

  Future<void> refresh() {
    if (_disposed) return Future.value();
    return _pending ??= _refresh().whenComplete(() => _pending = null);
  }

  Future<void> _refresh() async {
    _retry?.cancel();
    try {
      final token = await channel
          .invokeMapMethod<String, dynamic>('register')
          .timeout(const Duration(seconds: 30));
      if (_disposed) return;
      if (token == null) {
        await _removeRegistration();
        return;
      }
      if (token['bundleId'] != 'com.snow.aspire') {
        throw StateError('Unexpected app bundle for NX Main');
      }
      _registration = {
        'app': 'nx_main',
        'environment': token['environment'],
        'token': token['token'],
      };
      final response = await client
          .post(endpoint,
              headers: {'content-type': 'application/json'},
              body: jsonEncode(_registration))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw StateError('Push registration HTTP ${response.statusCode}');
      }
    } catch (_) {
      // Never log device tokens, auth headers, or notification contents.
      debugPrint('[Push] Registration unavailable; retrying in one minute');
      if (!_disposed) {
        await channel.invokeMethod<void>('unregister').catchError((_) {});
        _retry = Timer(const Duration(minutes: 1), () => unawaited(refresh()));
      }
    }
  }

  Future<void> _removeRegistration() async {
    final registration = _registration;
    if (registration == null) return;
    final response = await client
        .post(endpoint,
            headers: {'content-type': 'application/json'},
            body: jsonEncode({...registration, 'enabled': false}))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200)
      throw StateError('Push unregistration failed');
    _registration = null;
  }

  Future<void> logout() async {
    _disposed = true;
    _retry?.cancel();
    try {
      await channel.invokeMethod<void>('unregister');
      await _pending;
      await _removeRegistration();
    } catch (_) {
      debugPrint('[Push] Server unregistration unavailable during logout');
    }
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    if (identical(current, this)) current = null;
  }
}
