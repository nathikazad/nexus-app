import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/application/sessions/session_identity.dart';
import 'package:nexus_voice_assistant/application/sessions/session_coordinator.dart';
import 'package:nexus_voice_assistant/application/sessions/agent_routes.dart';

void main() {
  test(
      'ambient identity ignores selected domain but retires on account changes',
      () {
    final calls = <String>[];
    final coordinator = SessionCoordinator<String>(
        disconnectNecklace: () => calls.add('close'),
        configureWatch: (_) {},
        connectNecklace: (s) => calls.add(s));
    AmbientSessionIdentity identity(String uid) => AmbientSessionIdentity(
        backend: 'hosted', userId: uid, clientId: 'nx_main');
    coordinator.update(identity('1'), 'personal');
    coordinator.update(identity('1'), 'home');
    coordinator.update(identity('2'), 'other user');
    coordinator.update(null, null);
    expect(calls, ['personal', 'close', 'other user', 'close']);
  });
  test('necklace ambient headers exclude domain while app retains it', () {
    expect(AgentRoutes.necklace.headers(), {'X-Client-Id': 'necklace'});
    expect(AgentRoutes.app.headers(7)['X-Domain-Id'], '7');
    expect(AgentRoutes.app.headers().containsKey('X-Domain-Id'), isFalse);
    expect(() => AgentRoutes.app.headers(0), throwsStateError);
  });
}
