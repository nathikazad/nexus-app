/// Upgrades known public Nexus hosts to HTTPS.
String normalizeHttpEndpoint(String endpoint) {
  var ep = endpoint;
  final uri = Uri.tryParse(ep);
  final host = uri?.host ?? '';
  final isPublicNexusHost =
      host.endsWith('.kgql.io') ||
      host.endsWith('.nathikazad.com') ||
      host.endsWith('.supacharger.ai');
  if (isPublicNexusHost && ep.startsWith('http://')) {
    ep = ep.replaceFirst('http://', 'https://');
  }
  return ep;
}

/// Headers passed to [HttpLink] for GraphQL HTTP (matches [createClient]).
Map<String, String> buildHttpLinkDefaultHeaders(
  String endpoint,
  String userId,
) {
  return {'x-user-id': userId};
}
