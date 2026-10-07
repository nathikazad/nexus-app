import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/app_reads.dart';
import 'package:nx_observability/nx_observability.dart';
import 'package:nx_people/data/sync/people_data_repository.dart'
    show peopleOperationId;

final peopleSyncTelemetryProvider = Provider<PeopleSyncTelemetry?>((ref) {
  final reads = ref.watch(appReadsProvider('people'));
  if (reads == null) return null;
  final telemetry = PeopleSyncTelemetry(
    NxAppLogUploader(
      httpBaseUrl: reads.origin.toString(),
      origin: 'nx_people',
      httpClient: reads.client,
    ),
  );
  ref.onDispose(telemetry.close);
  return telemetry;
});

/// Best-effort diagnostics bound to the current server/user/domain client.
/// Never wait for logging on the sync path or retain events across accounts.
class PeopleSyncTelemetry {
  PeopleSyncTelemetry(this.uploader) : sessionId = peopleOperationId();
  final NxAppLogUploader uploader;
  final String sessionId;
  bool _closed = false;
  int _pending = 0;
  int _dropped = 0;

  void record(String event, Map<String, Object?> fields) {
    if (_closed) return;
    if (_pending >= 16) {
      _dropped++;
      return;
    }
    final dropped = _dropped;
    _dropped = 0;
    _pending++;
    unawaited(_upload(event, fields, dropped));
  }

  Future<void> _upload(
    String event,
    Map<String, Object?> fields,
    int dropped,
  ) async {
    try {
      await uploader.upload(
        eventName: 'sync.$event',
        category: 'sync',
        message: 'People sync: $event',
        severity: event.endsWith('failed') || event.endsWith('error')
            ? 'warning'
            : 'info',
        payload: {
          ...fields,
          'app': 'people',
          'session_id': sessionId,
          if (dropped > 0) 'dropped_events': dropped,
        },
      );
    } catch (_) {
      // A logging failure must never interrupt synchronization.
    } finally {
      _pending--;
    }
  }

  void close() {
    _closed = true;
  }
}
