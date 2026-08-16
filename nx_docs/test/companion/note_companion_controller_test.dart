import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:nx_docs/companion/note_ai_session.dart';
import 'package:nx_docs/companion/note_transcript.dart';
import 'package:nx_docs/documents/assets/document_audio_service.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/companion/note_companion_controller.dart';
import 'package:nx_voice/nx_voice.dart';
import 'package:nx_voice/stored_audio.dart';

class _FakeSocket implements NoteAiSocketPort {
  bool connected = false;
  void Function(NxVoiceTextChunk packet)? textChunk;
  void Function(NxVoiceTextEof packet)? textEof;

  @override
  set onAudioChunk(void Function(NxVoiceAudioChunk packet)? value) {}

  @override
  set onAudioEof(void Function(NxVoiceAudioEof packet)? value) {}

  @override
  set onTextChunk(void Function(NxVoiceTextChunk packet)? value) =>
      textChunk = value;

  @override
  set onTextEof(void Function(NxVoiceTextEof packet)? value) => textEof = value;

  @override
  set onError(void Function(Object error)? value) {}

  @override
  bool get isConnected => connected;

  @override
  Future<bool> connect(
    String url, {
    required Map<String, String> headers,
    required Future<Map<String, String>> Function(bool forceRefresh)
    authHeaders,
  }) async {
    connected = true;
    return true;
  }

  @override
  Future<void> disconnect({bool clearQueuedPackets = true}) async {
    connected = false;
  }

  @override
  void sendAudioChunk(
    Uint8List opus, {
    required int streamIndex,
    required int packetIndex,
    int? meta,
  }) {}

  @override
  void sendAudioEof({required int streamIndex, int? meta}) {}

  @override
  void sendTextTurn(String text, {required int streamIndex}) {}

  void emitText(String text, {int streamIndex = 1}) {
    textChunk?.call(NxVoiceTextChunk(text: text, streamIndex: streamIndex));
  }

  void emitTextEof({int streamIndex = 1}) {
    textEof?.call(NxVoiceTextEof(streamIndex: streamIndex));
  }
}

class _FakeTranscriptLoader implements NoteTranscriptLoader {
  _FakeTranscriptLoader([this.transcript]);

  final NoteTranscript? transcript;

  @override
  Future<NoteTranscript?> loadForDocument(int documentId) async => transcript;
}

class _FakeStoredAudioPlayer extends NxStoredAudioPlayer {
  double appliedSpeed = 1;

  @override
  Future<void> play(String url, {Duration? startAt, Duration? duration}) async {
    onPlaybackStateChanged?.call(true);
  }

  @override
  Future<void> pause() async {
    onPlaybackStateChanged?.call(false);
  }

  @override
  Future<void> setSpeed(double speed) async {
    appliedSpeed = speed;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('com.llfbandit.record/messages'),
        (_) async => null,
      );

  test('keeps assistant answers from separate text turns distinct', () async {
    final socket = _FakeSocket();
    final controller = NoteCompanionController(
      documentId: 4450,
      socketUrl: 'wss://socket.example',
      userId: '1',
      audioService: DocumentAudioService(baseUrl: 'https://notes.example'),
      transcriptLoader: _FakeTranscriptLoader(),
      session: NoteAiSession(socket: socket),
    );

    await controller.sendText('First question');
    socket.emitText('Draft one');
    socket.emitText(
      jsonEncode(<String, Object>{
        'type': 'transcript',
        'role': 'assistant',
        'text': 'First answer',
      }),
    );
    socket.emitTextEof();

    await controller.sendText('Follow-up question');
    socket.emitText('Draft two', streamIndex: 2);
    socket.emitText(
      jsonEncode(<String, Object>{
        'type': 'transcript',
        'role': 'assistant',
        'text': 'Second answer',
      }),
      streamIndex: 2,
    );
    socket.emitTextEof(streamIndex: 2);

    expect(
      controller.messages.map((message) => (message.role, message.text)),
      <(String, String)>[
        ('user', 'First question'),
        ('assistant', 'First answer'),
        ('user', 'Follow-up question'),
        ('assistant', 'Second answer'),
      ],
    );
  });

  test('shows six recent transcript messages then pages backward', () async {
    final storedMessages = <NoteTranscriptMessage>[];
    for (var index = 0; index < 20; index++) {
      final timestamp = '2026-08-06T12:00:${index.toString().padLeft(2, '0')}Z';
      storedMessages.add(
        NoteTranscriptMessage(
          timestamp: timestamp,
          sender: index.isEven ? 'Human' : 'Agent',
          message: 'Message $index',
        ),
      );
    }
    final controller = NoteCompanionController(
      documentId: 4450,
      socketUrl: 'wss://socket.example',
      userId: '1',
      audioService: DocumentAudioService(baseUrl: 'https://notes.example'),
      transcriptLoader: _FakeTranscriptLoader(
        NoteTranscript(id: 91, messages: storedMessages),
      ),
      session: NoteAiSession(socket: _FakeSocket()),
    );

    await controller.loadHistory();

    expect(controller.messages, hasLength(6));
    expect(controller.messages.first.text, 'Message 14');
    expect(controller.hasOlderMessages, isTrue);

    controller.loadOlderMessages();
    expect(controller.messages, hasLength(16));
    expect(controller.messages.first.text, 'Message 4');

    controller.loadOlderMessages();
    expect(controller.messages, hasLength(20));
    expect(controller.messages.first.text, 'Message 0');
    expect(controller.hasOlderMessages, isFalse);
  });

  test('reports playback so the mic action can become stop', () async {
    final controller = NoteCompanionController(
      documentId: 4450,
      socketUrl: 'wss://socket.example',
      userId: '1',
      audioService: DocumentAudioService(baseUrl: 'https://notes.example'),
      transcriptLoader: _FakeTranscriptLoader(),
      session: NoteAiSession(socket: _FakeSocket()),
      noteAudioPlayer: _FakeStoredAudioPlayer(),
      initialAudio: const DocumentAudio(
        url: 'https://notes.example/audio.opus',
        sourceHash: 'hash',
        manifest: DocumentAudioManifest(
          duration: Duration(seconds: 10),
          blocks: <DocumentAudioBlockTiming>[
            DocumentAudioBlockTiming(
              blockIndex: 0,
              blockKey: 'block-0',
              start: Duration.zero,
              end: Duration(seconds: 10),
            ),
          ],
        ),
      ),
    );

    await controller.toggleNoteAudio();
    expect(controller.anyAudioPlaying, isTrue);

    await controller.stopPlayback();
    expect(controller.anyAudioPlaying, isFalse);
  });

  test(
    'changes stored note playback speed without affecting voice audio',
    () async {
      final notePlayer = _FakeStoredAudioPlayer();
      final controller = NoteCompanionController(
        documentId: 4450,
        socketUrl: 'wss://socket.example',
        userId: '1',
        audioService: DocumentAudioService(baseUrl: 'https://notes.example'),
        transcriptLoader: _FakeTranscriptLoader(),
        session: NoteAiSession(socket: _FakeSocket()),
        noteAudioPlayer: notePlayer,
      );

      await controller.setNoteAudioPlaybackSpeed(1.5);

      expect(controller.noteAudioPlaybackSpeed, 1.5);
      expect(notePlayer.appliedSpeed, 1.5);
    },
  );
}
