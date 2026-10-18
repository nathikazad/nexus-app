import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_auth/nx_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('uploads auth lifecycle metadata without credentials', () async {
    late http.Request request;
    final recorder = AuthTelemetryRecorder(
      client: MockClient((captured) async {
        request = captured;
        return http.Response('{"ok":true}', 200);
      }),
    );

    await recorder.beginSession(
      app: 'nx_books',
      userId: '7',
      interactive: true,
      token: const {
        'access_token_lifetime_seconds': 43200,
        'has_refresh_token': true,
      },
    );
    await recorder.enqueue(
      app: 'nx_books',
      userId: '7',
      event: 'token_refresh_failed',
      fields: const {
        'source': 'manual',
        'failure_kind': 'terminal',
        'oauth_error_code': 'invalid_grant',
      },
    );
    await recorder.flush(
      preset: BackendPreset.hosted,
      app: 'nx_books',
      userId: '7',
      accessToken: 'upload-only-secret',
    );

    expect(request.url.path, '/logs/auth/upload');
    expect(request.headers['authorization'], 'Bearer upload-only-secret');
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final encodedRows = jsonEncode(body['rows']);
    expect(encodedRows, contains('auth.sign_in_succeeded'));
    expect(encodedRows, contains('auth.token_refresh_failed'));
    expect(encodedRows, contains('invalid_grant'));
    expect(encodedRows, isNot(contains('upload-only-secret')));
  });

  test(
    'retains rejected uploads and retries them after reauthentication',
    () async {
      var attempts = 0;
      final bodies = <String>[];
      final recorder = AuthTelemetryRecorder(
        client: MockClient((request) async {
          attempts++;
          bodies.add(request.body);
          return http.Response('', attempts == 1 ? 401 : 200);
        }),
      );
      await recorder.enqueue(
        app: 'nx_books',
        userId: '7',
        event: 'session_rejected',
      );
      for (var i = 0; i < 2; i++) {
        await recorder.flush(
          preset: BackendPreset.hosted,
          app: 'nx_books',
          userId: '7',
          accessToken: 'credential-$i',
        );
      }

      expect(attempts, 2);
      expect(bodies[1], contains('auth.session_rejected'));
    },
  );

  test('serializes concurrent flushes without duplicate uploads', () async {
    var attempts = 0;
    final firstRequest = Completer<void>();
    final releaseRequest = Completer<void>();
    final recorder = AuthTelemetryRecorder(
      client: MockClient((request) async {
        attempts++;
        firstRequest.complete();
        await releaseRequest.future;
        return http.Response('{"ok":true}', 200);
      }),
    );
    await recorder.enqueue(
      app: 'nx_books',
      userId: '7',
      event: 'session_restored',
    );

    final first = recorder.flush(
      preset: BackendPreset.hosted,
      app: 'nx_books',
      userId: '7',
      accessToken: 'credential',
    );
    await firstRequest.future;
    final second = recorder.flush(
      preset: BackendPreset.hosted,
      app: 'nx_books',
      userId: '7',
      accessToken: 'credential',
    );
    releaseRequest.complete();
    await Future.wait([first, second]);

    expect(attempts, 1);
  });
}
