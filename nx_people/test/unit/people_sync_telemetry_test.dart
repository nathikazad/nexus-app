import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_observability/nx_observability.dart';
import 'package:nx_people/data/sync/people_sync_telemetry.dart';

void main() {
  test(
    'uploads People sync metadata through the existing app logs endpoint',
    () async {
      final received = Completer<http.Request>();
      final logger = PeopleSyncTelemetry(
        NxAppLogUploader(
          httpBaseUrl: 'https://test.invalid',
          origin: 'nx_people',
          httpClient: MockClient((request) async {
            received.complete(request);
            return http.Response('{"ok":true}', 200);
          }),
        ),
      );
      logger.record('cache_applied', {
        'revision': 25,
        'root_hash': 'root25',
        'duration_ms': 8,
      });
      final request = await received.future;
      expect(request.url.path, '/logs/app/upload');
      final row = jsonDecode(request.body)['row'] as Map;
      expect(row['origin'], 'nx_people');
      expect(row['category'], 'sync');
      expect(row['event_name'], 'sync.cache_applied');
      expect(row['payload']['revision'], 25);
      expect(row['payload']['session_id'], logger.sessionId);
      logger.close();
    },
  );

  test(
    'bounds pending uploads and stops logging on session disposal',
    () async {
      final pending = <Completer<http.Response>>[];
      final logger = PeopleSyncTelemetry(
        NxAppLogUploader(
          httpBaseUrl: 'https://test.invalid',
          origin: 'nx_people',
          httpClient: MockClient((_) {
            final c = Completer<http.Response>();
            pending.add(c);
            return c.future;
          }),
        ),
      );
      for (var i = 0; i < 30; i++) {
        logger.record('check_started', {});
      }
      await Future<void>.delayed(Duration.zero);
      expect(pending.length, 16);
      logger.close();
      for (final c in pending) {
        c.complete(http.Response('', 500));
      }
      await Future<void>.delayed(Duration.zero);
      logger.record('client_state', {});
      await Future<void>.delayed(Duration.zero);
      expect(pending.length, 16);
    },
  );
}
