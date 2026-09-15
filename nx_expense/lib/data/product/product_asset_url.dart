import 'package:nx_db/auth.dart';

/// Resolve saved product image paths against the authenticated asset server.
String resolveProductAssetUrl(String imageBaseUrl, String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  var base = imageBaseUrl.trim();
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  base = normalizeHttpEndpoint(base);
  return '$base/${path.replaceFirst(RegExp(r'^/+'), '')}';
}
