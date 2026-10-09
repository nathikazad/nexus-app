import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_db/auth.dart';
import 'package:nexus_voice_assistant/data/push/push_registration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PushRegistrationSession.channel, null);
  });

  test('registration derives identity from client and logout removes token',
      () async {
    final requests = <http.Request>[];
    final nativeCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PushRegistrationSession.channel,
            (call) async {
      nativeCalls.add(call.method);
      return call.method == 'register'
          ? {
              'token': 'ab' * 32,
              'environment': 'sandbox',
              'bundleId': 'com.snow.aspire'
            }
          : null;
    });
    final client = NexusAuthenticatedClient(
      preset: BackendPreset.hosted,
      userId: '7',
      domainId: 11,
      authHeaders: (_) async => {'authorization': 'Bearer verified'},
      inner: MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 200);
      }),
    );
    final session = PushRegistrationSession(
        client: client,
        endpoint: Uri.parse('https://example.test/v1/push/register'));
    await session.refresh();
    await session.logout();
    expect(requests.length, 2);
    expect(requests[0].headers['authorization'], 'Bearer verified');
    expect(jsonDecode(requests[0].body)['app'], 'nx_main');
    expect(jsonDecode(requests[0].body).containsKey('user_id'), false);
    expect(jsonDecode(requests[1].body)['enabled'], false);
    expect(nativeCalls, ['register', 'unregister']);
    session.dispose();
    client.close();
  });

  test('logout waits for in-flight token upload before removing it', () async {
    final uploaded = Completer<void>();
    final release = Completer<void>();
    final bodies = <Map<String, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            PushRegistrationSession.channel,
            (call) async => call.method == 'register'
                ? {
                    'token': 'ab',
                    'environment': 'sandbox',
                    'bundleId': 'com.snow.aspire'
                  }
                : null);
    final client = NexusAuthenticatedClient(
      preset: BackendPreset.hosted,
      userId: '7',
      domainId: 11,
      authHeaders: (_) async => {'authorization': 'Bearer verified'},
      inner: MockClient((request) async {
        bodies.add(jsonDecode(request.body));
        if (bodies.length == 1) {
          uploaded.complete();
          await release.future;
        }
        return http.Response('{}', 200);
      }),
    );
    final session = PushRegistrationSession(
        client: client,
        endpoint: Uri.parse('https://example.test/v1/push/register'));
    final refresh = session.refresh();
    await uploaded.future;
    final logout = session.logout();
    release.complete();
    await refresh;
    await logout;
    expect(bodies.length, 2);
    expect(bodies.last['enabled'], false);
    session.dispose();
    client.close();
  });
}
