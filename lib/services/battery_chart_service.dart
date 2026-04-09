import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cf_access.dart';

/// One battery sample from GET /battery/day.
class BatteryPoint {
  const BatteryPoint({
    required this.timeHms,
    required this.percent,
    required this.voltageMv,
    required this.charging,
  });

  /// Wall-clock `HH:MM:SS` (server strips offset).
  final String timeHms;
  final int percent;
  final int voltageMv;
  final bool charging;
}

String _normalizeBase(String baseUrl) =>
    baseUrl.replaceAll(RegExp(r'/+$'), '');

Map<String, String> _headers(String baseUrl, String userId) => {
      'X-User-Id': userId,
      if (CfAccess.shouldAttachHeaders(baseUrl)) ...CfAccess.headers,
    };

/// Distinct calendar days with at least one necklace battery event.
Future<List<DateTime>> fetchBatteryDates(
  String baseUrl,
  String userId,
) async {
  final base = _normalizeBase(baseUrl);
  final uri = Uri.parse('$base/battery/dates');
  final response = await http.get(uri, headers: _headers(baseUrl, userId));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw BatteryChartException(
      'GET /battery/dates failed: ${response.statusCode} ${response.body}',
    );
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    throw BatteryChartException('Invalid JSON for /battery/dates');
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
}

/// All battery samples for [day].
Future<List<BatteryPoint>> fetchBatteryDay(
  String baseUrl,
  String userId,
  DateTime day,
) async {
  final base = _normalizeBase(baseUrl);
  final dateStr =
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  final uri = Uri.parse('$base/battery/day').replace(
    queryParameters: {'date': dateStr},
  );
  final response = await http.get(uri, headers: _headers(baseUrl, userId));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw BatteryChartException(
      'GET /battery/day failed: ${response.statusCode} ${response.body}',
    );
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    throw BatteryChartException('Invalid JSON for /battery/day');
  }
  final raw = decoded['points'];
  if (raw is! List) return [];
  final out = <BatteryPoint>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    final t = item['time'];
    if (t is! String) continue;
    final pctRaw = item['battery_pct'];
    final vmv = item['voltage_mv'];
    final chg = item['charging'];
    final pct = pctRaw is int
        ? pctRaw
        : pctRaw is num
            ? pctRaw.round()
            : int.tryParse('$pctRaw');
    if (pct == null) continue;
    out.add(
      BatteryPoint(
        timeHms: t,
        percent: pct,
        voltageMv: vmv is int
            ? vmv
            : vmv is num
                ? vmv.round()
                : int.tryParse('$vmv') ?? 0,
        charging: chg == true || chg == 1,
      ),
    );
  }
  return out;
}

class BatteryChartException implements Exception {
  BatteryChartException(this.message);
  final String message;

  @override
  String toString() => 'BatteryChartException: $message';
}
