/// Manifest image keys and chapter filenames share the OPF-relative namespace.
/// Resolve the image URL against its chapter, not against the archive root.
String? resolveEpubImageKey(String source, String chapter, Iterable<String> keys) {
  try {
    final link = Uri.parse(source);
    if (link.hasScheme || link.hasAuthority || link.path.isEmpty) return null;
    String normalized(Uri uri) => Uri.decodeComponent(uri.normalizePath().path);
    final target = normalized(Uri.parse('/$chapter').resolveUri(link));
    for (final key in keys) {
      if (normalized(Uri.parse('/$key')) == target) return key;
    }
  } on FormatException {
    return null;
  }
  return null;
}
