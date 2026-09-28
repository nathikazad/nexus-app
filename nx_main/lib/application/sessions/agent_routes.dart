/// Source routing is policy, separate from transport or UI lifecycle.
class AgentRoute {
  const AgentRoute({required this.clientId});
  final String clientId;

  Map<String, String> headers([int? domainId]) {
    if (domainId != null && domainId <= 0) {
      throw StateError('Domain ID must be positive.');
    }
    return {
      if (domainId != null) 'X-Domain-Id': '$domainId',
      'X-Client-Id': clientId,
    };
  }
}

abstract final class AgentRoutes {
  static const app = AgentRoute(clientId: 'nx_main');
  static const necklace = AgentRoute(clientId: 'necklace');
  static const watch = AgentRoute(clientId: 'nx_watch');
}
