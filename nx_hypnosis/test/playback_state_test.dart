import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_hypnosis/desires.dart';
import 'package:nx_hypnosis/listening.dart';
import 'package:nx_hypnosis/playback_state.dart';

PlaybackCheckpoint saved({
  int position = 42000,
  int updated = 100,
  String? revision = 'a',
}) => PlaybackCheckpoint(
  tapeId: '12',
  audioRevision: revision,
  positionMs: position,
  repeat: true,
  speed: 1.25,
  updatedAtMs: updated,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Listening listening;
  late List<Tape> tapes;
  late List<String> writes;
  late PlaybackState state;
  setUp(() {
    listening = Listening();
    tapes = [
      Tape(
        id: '12',
        desireId: '1',
        title: 'Test',
        story: '',
        audioAsset: 'recording.mp3',
        audioRevision: 'a',
      ),
    ];
    writes = [];
  });
  tearDown(() {
    state.dispose();
    listening.dispose();
  });
  PlaybackState create({
    String? local,
    Future<PlaybackCheckpoint?> Function(PlaybackCheckpoint?)? exchange,
  }) => state = PlaybackState(
    listening: listening,
    tapes: () => tapes,
    readLocal: () async => local,
    writeLocal: (s) async {
      writes.add(s);
    },
    exchange: exchange ?? (_) async => throw StateError('offline'),
  );

  test(
    'offline restart restores position, repeat and speed without autoplay',
    () async {
      await create(local: jsonEncode(saved().toJson())).initialize();
      expect(listening.tape?.id, '12');
      expect(listening.position.inMilliseconds, 42000);
      expect(listening.repeatEnabled, true);
      expect(listening.speed, 1.25);
      expect(listening.playing, false);
      expect(listening.loading, false);
    },
  );

  test('seek is saved locally and unsent progress survives restart', () async {
    await create(local: jsonEncode(saved().toJson())).initialize();
    await listening.seek(const Duration(seconds: 73));
    await Future<void>.delayed(Duration.zero);
    final last = PlaybackCheckpoint.parse(jsonDecode(writes.last))!;
    expect(last.positionMs, 73000);
    expect(last.updatedAtMs, greaterThan(100));
    expect(last.repeat, true);
  });

  test('newer remote checkpoint replaces older local progress', () async {
    await create(
      local: jsonEncode(saved().toJson()),
      exchange: (_) async => saved(position: 90000, updated: 200),
    ).initialize();
    expect(listening.position.inMilliseconds, 90000);
  });

  test('late server response cannot overwrite a newer local seek', () async {
    final response = Completer<PlaybackCheckpoint?>();
    final entered = Completer<void>();
    final initializing = create(
      local: jsonEncode(saved().toJson()),
      exchange: (_) {
        entered.complete();
        return response.future;
      },
    ).initialize();
    await entered.future;
    await listening.seek(const Duration(seconds: 85));
    response.complete(saved(position: 90000, updated: 200));
    await initializing;
    expect(listening.position.inSeconds, 85);
    expect(state.current!.positionMs, 85000);
  });

  test('regenerated recording resets position but keeps settings', () async {
    await create(
      local: jsonEncode(saved(revision: 'old').toJson()),
    ).initialize();
    expect(listening.position, Duration.zero);
    expect(listening.repeatEnabled, true);
  });

  test(
    'missing tape checkpoint waits for library instead of being cleared',
    () async {
      final tape = tapes.removeLast();
      await create(local: jsonEncode(saved().toJson())).initialize();
      state.capture();
      expect(state.current!.tapeId, '12');
      tapes.add(tape);
      state.libraryChanged();
      expect(listening.position.inSeconds, 42);
    },
  );

  test(
    'close persists empty selection and does not resurrect old tape',
    () async {
      await create(local: jsonEncode(saved().toJson())).initialize();
      await listening.close();
      expect(state.current!.tapeId, isNull);
      state.libraryChanged();
      expect(listening.tape, isNull);
    },
  );

  test('temporary loading position never overwrites checkpoint', () async {
    await create(local: jsonEncode(saved().toJson())).initialize();
    listening.opening = true;
    listening.position = Duration.zero;
    state.capture();
    expect(state.current!.positionMs, 42000);
    listening.opening = false;
  });

  test('malformed local checkpoint falls back to remote', () async {
    await create(local: '{bad', exchange: (_) async => saved()).initialize();
    expect(listening.position.inSeconds, 42);
  });
}
