import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/push/push_haptics.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1000000);
  Map<String, dynamic> notification() => {
        'id': 'test',
        'user_id': '7',
        'app': 'nx_main',
        'necklace': true,
        'sent_at': 1000,
      };
  test('foreground and background callbacks pulse only once while pending',
      () async {
    var count = 0;
    final done = Completer<bool>();
    final handler = PushHaptics(
        userId: '7',
        now: () => now,
        pulse: () {
          count++;
          return done.future;
        });
    final first = handler.receive(notification());
    expect(await handler.receive(notification()), false);
    done.complete(true);
    expect(await first, true);
    expect(count, 1);
  });
  test('other accounts, stale alerts and other apps never pulse', () async {
    var count = 0;
    final handler = PushHaptics(
        userId: '7',
        now: () => now,
        pulse: () async {
          count++;
          return true;
        });
    for (final change in [
      {'user_id': '8'},
      {'sent_at': 900},
      {'app': 'nx_docs'},
      {'necklace': false}
    ]) {
      expect(await handler.receive({...notification(), ...change}), false);
    }
    expect(count, 0);
  });
  test('disconnected or failed pulses are not replayed later', () async {
    var connected = false;
    var count = 0;
    final handler = PushHaptics(
        userId: '7',
        now: () => now,
        pulse: () async {
          count++;
          return connected;
        });
    expect(await handler.receive(notification()), false);
    connected = true;
    expect(await handler.receive(notification()), false);
    expect(await handler.receive({...notification(), 'id': 'new'}), true);
    expect(count, 2);
  });
  test('target phone suppresses haptics even with conflicting legacy flag',
      () async {
    var count = 0;
    final handler = PushHaptics(
        userId: '7',
        now: () => now,
        pulse: () async {
          count++;
          return true;
        });
    expect(
        await handler.receive({...notification(), 'target': 'phone'}), false);
    expect(
        await handler.receive({...notification(), 'target': 'invalid'}), false);
    expect(await handler.receive({...notification(), 'target': 'both'}), true);
    expect(
        await handler
            .receive({...notification(), 'id': 'second', 'target': 'necklace'}),
        true);
    expect(count, 2);
  });
}
