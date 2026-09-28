import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/application/sessions/agent_routes.dart';
import 'package:nexus_voice_assistant/application/sessions/session_identity.dart';
import 'package:nexus_voice_assistant/application/sessions/session_coordinator.dart';
import 'package:nexus_voice_assistant/data/background/background_session_command.dart';
import 'package:nx_db/auth.dart';

void main() {
  SessionIdentity identity(
          {String backend = 'backend',
          String user = '1',
          int domain = 7,
          String app = 'nx_main'}) =>
      SessionIdentity(
          backend: backend, userId: user, domainId: domain, clientId: app);
  test('identity requires a domain and distinguishes every ownership dimension',
      () {
    expect(() => identity(domain: 0), throwsStateError);
    expect(identity(), identity());
    for (final other in [
      identity(backend: 'other'),
      identity(user: '2'),
      identity(domain: 8),
      identity(app: 'nx_watch')
    ]) {
      expect(identity(), isNot(other));
    }
  });
  test(
      'switch retires necklace before configuring destinations; duplicate is a no-op',
      () {
    final calls = <String>[];
    final coordinator = SessionCoordinator<String>(
        disconnectNecklace: () => calls.add('disconnect'),
        configureWatch: (c) => calls.add('watch:$c'),
        connectNecklace: (c) => calls.add('necklace:$c'));
    coordinator.update(identity(), 'first');
    coordinator.update(identity(), 'duplicate');
    coordinator.update(identity(domain: 8), 'second');
    coordinator.update(null, null);
    expect(calls, [
      'watch:first',
      'necklace:first',
      'disconnect',
      'watch:second',
      'necklace:second',
      'disconnect',
      'watch:null'
    ]);
  });
  test('routing preserves phone versus wearable agent and source headers', () {
    expect(AgentRoutes.app.headers(7), {
      'X-Nexus-Domain-Id': '7',
      'X-Client-Id': 'nx_main',
    });
    expect(AgentRoutes.necklace.headers(7), {
      'X-Nexus-Domain-Id': '7',
      'X-Client-Id': 'necklace',
    });
    expect(AgentRoutes.watch.headers(7), {
      'X-Nexus-Domain-Id': '7',
      'X-Client-Id': 'nx_watch',
    });
    expect(() => AgentRoutes.necklace.headers(0), throwsStateError);
  });
  test('ambient isolate boundary excludes selected domain and requires user',
      () {
    final config = BackgroundSessionCommand(
        url: 'ws://localhost:1',
        telemetryHttpBaseUrl: 'http://localhost:2',
        userId: '1',
        preset: BackendPreset.piLan,
        clientAppId: 'nx_main');
    expect(BackgroundSessionCommand.fromMap(config.toMap()).identity,
        config.identity);
    expect(config.toMap().containsKey('domainId'), isFalse);
    final missing = config.toMap()..remove('userId');
    expect(() => BackgroundSessionCommand.fromMap(missing),
        throwsA(isA<TypeError>()));
  });
}
