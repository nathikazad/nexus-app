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

  test(
    'failed sign-ins survive restart without leaking error contents or crossing accounts',
    () async {
      final recorder = AuthTelemetryRecorder();
      await recorder.signInFailed(
        app: 'nx_books',
        userId: null,
        phase: 'authentication',
        elapsedMilliseconds: 42,
        error: Exception(
          'https://callback?code=secret-code&token=secret-token',
        ),
      );
      await recorder.signInFailed(
        app: 'nx_books',
        userId: '8',
        phase: 'domain_selection',
        elapsedMilliseconds: 80,
        error: Exception('private account details'),
      );
      var status = 401;
      final requests = <http.Request>[];
      final restarted = AuthTelemetryRecorder(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('', status);
        }),
      );
      Future<void> flush(String user) => restarted.flush(
        preset: BackendPreset.hosted,
        app: 'nx_books',
        userId: user,
        accessToken: 'credential',
      );
      await flush('7');
      status = 200;
      await flush('7');
      await flush('7');
      expect(requests, hasLength(2));
      expect(requests[0].body, requests[1].body);
      final row =
          (jsonDecode(requests.last.body)['rows'] as List).single as Map;
      expect(row['event_name'], 'auth.sign_in_failed');
      expect(row['severity'], 'warning');
      expect(row['payload']['user_id'], '7');
      expect(row['payload']['phase'], 'authentication');
      expect(row['payload']['elapsed_ms'], 42);
      expect(requests.last.body, isNot(contains('secret-')));
      expect(requests.last.body, isNot(contains('private account')));
      await flush('8');
      expect(requests, hasLength(3));
      expect(requests.last.body, contains('domain_selection'));
    },
  );

  test(
    'token rejection is distinguished from cancellation without claim values',
    () async {
      final recorder = AuthTelemetryRecorder();
      final reason = authValidationReason(
        'id token contains untrusted audience(s) [private-client]',
      );
      expect(reason, 'audience');
      await recorder.signInFailed(
        app: 'nx_books',
        userId: '7',
        phase: 'authentication',
        elapsedMilliseconds: 10,
        error: AuthSignInValidationFailed([reason]),
      );
      final prefs = await SharedPreferences.getInstance();
      final queued = prefs.getString('nexus.auth.telemetry.queue.nx_books.7')!;
      expect(queued, contains('token_validation'));
      expect(queued, contains('audience'));
      expect(queued, isNot(contains('private-client')));
    },
  );

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

  test('records one restore when auth initializes twice', () async {
    late List<dynamic> rows;
    final recorder = AuthTelemetryRecorder(
      client: MockClient((request) async {
        rows =
            (jsonDecode(request.body) as Map<String, dynamic>)['rows']
                as List<dynamic>;
        return http.Response('{"ok":true}', 200);
      }),
    );

    for (var i = 0; i < 2; i++) {
      await recorder.beginSession(
        app: 'nx_books',
        userId: '7',
        interactive: false,
        token: const {'access_token_lifetime_seconds': 43200},
      );
    }
    await recorder.flush(
      preset: BackendPreset.hosted,
      app: 'nx_books',
      userId: '7',
      accessToken: 'credential',
    );

    expect(rows, hasLength(1));
    expect(
      (rows.single as Map<String, dynamic>)['event_name'],
      'auth.session_restored',
    );
  });
}
