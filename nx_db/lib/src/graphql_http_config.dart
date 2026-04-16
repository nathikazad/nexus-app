import 'cf_access.dart';

/// Upgrades `http://` to `https://` for Cloudflare tunnel hostnames.
String normalizeHttpEndpointForCf(String endpoint) {
  var ep = endpoint;
  if (CfAccess.endpointNeedsCfAccess(ep) && ep.startsWith('http://')) {
    ep = ep.replaceFirst('http://', 'https://');
  }
  return ep;
}

/// Headers passed to [HttpLink] for GraphQL HTTP (matches [createClient]).
Map<String, String> buildHttpLinkDefaultHeaders(String endpoint, String userId) {
  final attachCf = CfAccess.shouldAttachHeaders(endpoint);
  final cf = attachCf ? CfAccess.headers : const <String, String>{};
  return {
    'x-user-id': userId,
    ...cf,
  };
}
