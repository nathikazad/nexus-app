import 'dart:convert';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

import '../cf_access.dart';

/// Disk cache for image GETs (lazy-loaded by [CachedNetworkImage]).
final imageCacheManager = CacheManager(
  Config(
    'nexus_images',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 1000,
  ),
);

/// Headers for image HTTP API and [CachedNetworkImage] (`X-User-Id`, optional CF Access).
Map<String, String> imageHeaders(String baseUrl, String userId) => {
      'X-User-Id': userId,
      if (CfAccess.shouldAttachHeaders(baseUrl)) ...CfAccess.headers,
    };

/// Strips trailing slashes from [baseUrl] for joining paths.
String _normalizeBase(String baseUrl) =>
    baseUrl.replaceAll(RegExp(r'/+$'), '');

/// One image for a day, with URL and time derived from filename.
class ImageEntry {
  const ImageEntry({
    required this.url,
    required this.filename,
    required this.minutesSinceMidnight,
    this.currentApp,
  });

  final String url;
  final String filename;

  /// Fractional minutes since local midnight (seconds included as fraction).
  final double minutesSinceMidnight;

  /// Frontmost app name from `payload.current_app` (desktop screenshots), if present.
  final String? currentApp;
}

/// Parses `name` query from [url] and returns minutes since midnight, or null.
/// Desktop and necklace both use `YYMMDDHHmmss` as the filename stem.
double? minutesFromImageFilename(String url) {
  final name = Uri.parse(url).queryParameters['name'];
  if (name == null || name.isEmpty) return null;
  final stem = name.contains('.')
      ? name.substring(0, name.lastIndexOf('.'))
      : name;

  if (stem.length < 12 || !_allDigits(stem.substring(0, 12))) return null;
  final hh = int.tryParse(stem.substring(6, 8));
  final mm = int.tryParse(stem.substring(8, 10));
  final ss = int.tryParse(stem.substring(10, 12));
  if (hh == null || mm == null || ss == null) return null;
  return hh * 60.0 + mm + ss / 60.0;
}

bool _allDigits(String s) {
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c < 0x30 || c > 0x39) return false;
  }
  return true;
}

/// Fetches calendar days that have at least one image for [source] (`necklace` or `desktop`).
///
/// Calls `GET {baseUrl}/images/dates?source=...` with `X-User-Id` and optional Cloudflare Access headers.
Future<List<DateTime>> fetchAvailableDates(
  String baseUrl,
  String userId,
  String source,
) async {
  final base = _normalizeBase(baseUrl);
  final uri = Uri.parse('$base/images/dates').replace(
    queryParameters: {'source': source},
  );

  final response = await http.get(uri, headers: imageHeaders(baseUrl, userId));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ImageServiceException(
      'GET /images/dates failed: ${response.statusCode} ${response.body}',
    );
  }

  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    throw ImageServiceException('Invalid JSON for /images/dates');
  }

  final raw = decoded['dates'];
  if (raw is! List) {
    return [];
  }

  final out = <DateTime>[];
  for (final item in raw) {
    if (item is! String) continue;
    final d = DateTime.tryParse(item);
    if (d == null) continue;
    out.add(DateTime(d.year, d.month, d.day));
  }
  out.sort();
  return out;
}

/// Lists image URLs for one calendar day (metadata only; bytes loaded on demand).
Future<List<ImageEntry>> fetchImagesForDay(
  String baseUrl,
  String userId,
  String source,
  DateTime day,
) async {
  final base = _normalizeBase(baseUrl);
  final dateStr =
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  final uri = Uri.parse('$base/images/day').replace(
    queryParameters: {
      'date': dateStr,
      'source': source,
    },
  );

  final response = await http.get(uri, headers: imageHeaders(baseUrl, userId));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ImageServiceException(
      'GET /images/day failed: ${response.statusCode} ${response.body}',
    );
  }

  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    throw ImageServiceException('Invalid JSON for /images/day');
  }

  final raw = decoded['images'];
  if (raw is! List) {
    return [];
  }

  final out = <ImageEntry>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    final url = item['url'];
    if (url is! String) continue;
    final name = Uri.parse(url).queryParameters['name'] ?? '';
    final m = minutesFromImageFilename(url);
    if (m == null) continue;
    final currentApp = item['current_app'] as String?;
    out.add(ImageEntry(
      url: url,
      filename: name,
      minutesSinceMidnight: m,
      currentApp: currentApp,
    ));
  }
  return out;
}

class ImageServiceException implements Exception {
  ImageServiceException(this.message);
  final String message;

  @override
  String toString() => 'ImageServiceException: $message';
}
