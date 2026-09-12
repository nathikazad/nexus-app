/// Portable source metadata. No KGQL calls, UI widgets or renderer indexes.
class BookSource {
  const BookSource({
    required this.bookId,
    required this.sha256,
    required this.resource,
    this.fragment,
    this.exact,
    this.prefix,
    this.suffix,
  });
  final int bookId;
  final String sha256;

  /// Archive-root-relative path, not a URL or filesystem path.
  final String resource;
  final String? fragment, exact, prefix, suffix;

  static BookSource? fromJson(Object? value) {
    if (value is! Map || value['version'] != 1) return null;
    final id = value['book_id'],
        hash = value['sha256'],
        resource = value['resource'];
    if (id is! int ||
        id <= 0 ||
        hash is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        resource is! String ||
        resource.isEmpty ||
        resource.startsWith('/') ||
        resource.contains('\\') ||
        resource.split('/').any((s) => s == '..' || s.isEmpty) ||
        Uri.tryParse(resource)?.hasScheme != false ||
        resource.contains('#') ||
        resource.contains('?')) {
      return null;
    }
    final fragment = value['fragment'];
    final quote = value['quote'];
    if (fragment != null && (fragment is! String || fragment.trim().isEmpty)) {
      return null;
    }
    if (quote != null && quote is! Map) return null;
    final exact = quote is Map ? quote['exact'] : null;
    final prefix = quote is Map ? quote['prefix'] : null;
    final suffix = quote is Map ? quote['suffix'] : null;
    if (exact != null && (exact is! String || exact.trim().isEmpty)) {
      return null;
    }
    if (prefix != null && prefix is! String ||
        suffix != null && suffix is! String) {
      return null;
    }
    if (fragment == null && exact == null) return null;
    return BookSource(
      bookId: id,
      sha256: hash,
      resource: resource,
      fragment: fragment as String?,
      exact: exact as String?,
      prefix: prefix as String?,
      suffix: suffix as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'book_id': bookId,
    'sha256': sha256,
    'resource': resource,
    if (fragment != null) 'fragment': fragment,
    if (exact != null)
      'quote': {
        'exact': exact,
        if (prefix != null) 'prefix': prefix,
        if (suffix != null) 'suffix': suffix,
      },
  };
}
