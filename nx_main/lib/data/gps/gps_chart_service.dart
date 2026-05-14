import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nx_db/nx_db.dart';

import 'package:nexus_voice_assistant/domain/gps/gps_point.dart';

String _normalizeBase(String baseUrl) => baseUrl.replaceAll(RegExp(r'/+$'), '');

Map<String, String> _headers(String baseUrl, String userId) => {
      'X-User-Id': userId,
      if (CfAccess.shouldAttachHeaders(baseUrl)) ...CfAccess.headers,
    };

String _dateString(DateTime day) {
  return '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

Future<List<DateTime>> fetchGpsDates(
  String baseUrl,
  String userId, {
  http.Client? httpClient,
}) async {
  final client = httpClient ?? http.Client();
  final closeClient = httpClient == null;
  try {
    final base = _normalizeBase(baseUrl);
    final response = await client.get(
      Uri.parse('$base/gps/dates'),
      headers: _headers(baseUrl, userId),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GpsChartException(
        'GET /gps/dates failed: ${response.statusCode} ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw GpsChartException('Invalid JSON for /gps/dates');
    }
    final raw = decoded['dates'];
    if (raw is! List) return [];
    final out = <DateTime>[];
    for (final item in raw) {
      if (item is! String) continue;
      final d = DateTime.tryParse(item);
      if (d == null) continue;
      out.add(DateTime(d.year, d.month, d.day));
    }
    out.sort();
    return out;
  } finally {
    if (closeClient) client.close();
  }
}

Future<List<GpsPoint>> fetchGpsDay(
  String baseUrl,
  String userId,
  DateTime day, {
  http.Client? httpClient,
}) async {
  final client = httpClient ?? http.Client();
  final closeClient = httpClient == null;
  try {
    final base = _normalizeBase(baseUrl);
    final response = await client.get(
      Uri.parse('$base/gps/day').replace(
        queryParameters: {'date': _dateString(day)},
      ),
      headers: _headers(baseUrl, userId),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GpsChartException(
        'GET /gps/day failed: ${response.statusCode} ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw GpsChartException('Invalid JSON for /gps/day');
    }
    final raw = decoded['points'];
    if (raw is! List) return [];
    final out = <GpsPoint>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final time = item['time'];
      final timeIso = item['time_iso'];
      final lat = _doubleOrNull(item['latitude']);
      final lon = _doubleOrNull(item['longitude']);
      if (time is! String || timeIso is! String || lat == null || lon == null) {
        continue;
      }
      out.add(
        GpsPoint(
          timeHms: time,
          timeIso: timeIso,
          latitude: lat,
          longitude: lon,
          accuracyM: _doubleOrNull(item['accuracy_m']),
          altitudeM: _doubleOrNull(item['altitude_m']),
          speedMps: _doubleOrNull(item['speed_mps']),
          headingDeg: _doubleOrNull(item['heading_deg']),
          isMocked:
              item['is_mocked'] is bool ? item['is_mocked'] as bool : null,
        ),
      );
    }
    return out;
  } finally {
    if (closeClient) client.close();
  }
}

double? _doubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

class GpsChartException implements Exception {
  GpsChartException(this.message);
  final String message;

  @override
  String toString() => 'GpsChartException: $message';
}
