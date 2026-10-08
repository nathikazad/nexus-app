import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/diagnostics/necklace_diagnostics.dart';

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('necklace-diagnostics-');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('persists ordered metadata and snapshots caller fields', () async {
    final journal = NecklaceDiagnostics(directory: () async => dir);
    final fields = <String, Object?>{'bytes': 42};
    journal.record('ble.audio_notification', fields);
    fields['bytes'] = 99;
    journal.record('socket.sink_accepted', {'bytes': 42});
    await journal.flush();
    final rows = (await File('${dir.path}/necklace.jsonl').readAsLines())
        .map(jsonDecode)
        .toList();
    expect(rows.map((r) => r['event']),
        ['ble.audio_notification', 'socket.sink_accepted']);
    expect(rows.first['bytes'], 42);
    expect(DateTime.parse(rows.first['time']).isUtc, isTrue);
  });

  test('rotates to one previous file', () async {
    final journal =
        NecklaceDiagnostics(directory: () async => dir, maxBytes: 130);
    for (var i = 0; i < 6; i++) {
      journal.record('event', {'index': i});
    }
    await journal.flush();
    expect((await dir.list().toList()).length, 2);
    final row = jsonDecode(
        (await File('${dir.path}/necklace.jsonl').readAsLines()).last);
    expect(row['index'], 5);
  });

  test('storage failure is isolated and next event retries', () async {
    var fail = true;
    final journal = NecklaceDiagnostics(directory: () async {
      if (fail) throw const FileSystemException('unavailable');
      return dir;
    });
    journal.record('lost');
    await journal.flush();
    fail = false;
    journal.record('recovered');
    await journal.flush();
    final row =
        jsonDecode(await File('${dir.path}/necklace.jsonl').readAsString());
    expect(row['event'], 'recovered');
    expect(row['dropped'], 1);
  });

  test('bounds pending writes and reports overflow', () async {
    final gate = Completer<Directory>();
    final journal =
        NecklaceDiagnostics(directory: () => gate.future, maxPending: 2);
    journal.record('one');
    journal.record('two');
    journal.record('dropped');
    gate.complete(dir);
    await journal.flush();
    journal.record('four');
    await journal.flush();
    final rows = (await File('${dir.path}/necklace.jsonl').readAsLines())
        .map(jsonDecode)
        .toList();
    expect(rows.length, 3);
    expect(rows.last['dropped'], 1);
  });
}
