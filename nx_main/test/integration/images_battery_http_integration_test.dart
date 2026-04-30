@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/battery/battery_chart_service.dart';
import 'package:nx_db/nx_db.dart';

/// Live HTTP checks against the image/battery JSON API.
///
/// Requires:
/// - `RUN_NX_MAIN_HTTP_INTEGRATION=true`
/// - `NX_MAIN_IMAGE_BASE` — e.g. `https://…` (no trailing slash required)
/// - `NX_MAIN_USER_ID` — optional, defaults to `1`
void main() {
  if (Platform.environment['RUN_NX_MAIN_HTTP_INTEGRATION'] != 'true') {
    test(
      'HTTP image/battery integration skipped',
      () {},
      skip:
          'Set RUN_NX_MAIN_HTTP_INTEGRATION=true and NX_MAIN_IMAGE_BASE=…',
    );
    return;
  }

  final base = Platform.environment['NX_MAIN_IMAGE_BASE'];
  final uid = Platform.environment['NX_MAIN_USER_ID'] ?? '1';

  if (base == null || base.isEmpty) {
    test('NX_MAIN_IMAGE_BASE missing', () {
      fail('Set NX_MAIN_IMAGE_BASE when running HTTP integration tests');
    });
    return;
  }

  test('fetchAvailableDates returns a list', () async {
    final dates = await fetchAvailableDates(base, uid, 'necklace');
    expect(dates, isA<List<DateTime>>());
  });

  test('fetchBatteryDates returns a list', () async {
    final dates = await fetchBatteryDates(base, uid);
    expect(dates, isA<List<DateTime>>());
  });
}
