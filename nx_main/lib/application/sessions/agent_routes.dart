/// Source routing is policy, separate from transport or UI lifecycle.
class AgentRoute {
  const AgentRoute(
      {required this.clientApp, required this.agentId, this.source});
  final String clientApp;
  final String agentId;
  final String? source;

  Map<String, String> headers([int? domainId]) {
    if (domainId != null && domainId <= 0) {
      throw StateError('Domain ID must be positive.');
    }
    return {
      if (domainId != null) 'X-Nexus-Domain-Id': '$domainId',
      'X-Client-App': clientApp,
      'X-Agent-Id': agentId,
      if (source != null) 'X-Device-Source': source!,
    };
  }
}

abstract final class AgentRoutes {
  static const app = AgentRoute(clientApp: 'nx_main', agentId: 'nx_main');
  static const necklace = AgentRoute(
      clientApp: 'nx_main', agentId: 'personal_assistant', source: 'necklace');
  static const watch = AgentRoute(
      clientApp: 'nx_watch', agentId: 'personal_assistant', source: 'nx_watch');
}
