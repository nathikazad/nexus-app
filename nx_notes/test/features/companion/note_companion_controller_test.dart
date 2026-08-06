import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/data/ai/note_ai_session.dart';
import 'package:nx_notes/data/document/document_audio_service.dart';
import 'package:nx_notes/features/companion/note_companion_controller.dart';
import 'package:nx_utils/nx_utils.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps assistant answers from separate text turns distinct', () async {
    final socket = _FakeSocket();
    final controller = NoteCompanionController(
      documentId: 4450,
      socketUrl: 'wss://socket.example',
      userId: '1',
      audioService: DocumentAudioService(
        baseUrl: 'https://notes.example',
        userId: '1',
      ),
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
}
