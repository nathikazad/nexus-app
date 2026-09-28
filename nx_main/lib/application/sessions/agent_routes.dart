/// Source routing is policy, separate from transport or UI lifecycle.
class AgentRoute {
  const AgentRoute({required this.clientId});
  final String clientId;

  Map<String, String> ambientHeaders() {
    if (!const {'necklace', 'nx_watch', 'sleepbot_assistant', 'sleepbot_radar'}.contains(clientId)) {
      throw StateError('Ambient mode requires a device assistant route.');
    }
    return {
      'X-Nexus-Session-Mode': 'ambient',
      'X-Client-Id': clientId,
    };
  }

  Map<String, String> headers(int domainId) {
    if (domainId <= 0) throw StateError('A selected domain is required.');
    return {
      'X-Nexus-Domain-Id': '$domainId',
      'X-Client-Id': clientId,
    };
  }
}

abstract final class AgentRoutes {
  static const app = AgentRoute(clientId: 'nx_main');
  static const necklace =
      AgentRoute(clientId: 'necklace');
  static const watch =
      AgentRoute(clientId: 'nx_watch');
}
