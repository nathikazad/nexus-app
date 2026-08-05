import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/data/ai/note_ai_session.dart';
import 'package:nx_utils/nx_utils.dart';

class _FakeSocket implements NoteAiSocketPort {
  bool connected = false;
  int disconnects = 0;
  String? url;
  Map<String, String>? headers;
  final List<String> textTurns = <String>[];
  final List<Uint8List> audioPackets = <Uint8List>[];
  int audioEofs = 0;

  @override
  set onAudioChunk(void Function(NxVoiceAudioChunk packet)? value) {}

  @override
  set onAudioEof(void Function(NxVoiceAudioEof packet)? value) {}

  @override
  set onTextChunk(void Function(NxVoiceTextChunk packet)? value) {}

  @override
  set onTextEof(void Function(NxVoiceTextEof packet)? value) {}

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
    this.url = url;
    this.headers = headers;
    return true;
  }

  @override
  Future<void> disconnect({bool clearQueuedPackets = true}) async {
    connected = false;
    disconnects++;
  }

  @override
  void sendAudioChunk(
    Uint8List opus, {
    required int streamIndex,
    required int packetIndex,
    int? meta,
  }) {
    audioPackets.add(opus);
  }

  @override
  void sendAudioEof({required int streamIndex, int? meta}) {
    audioEofs++;
  }

  @override
  void sendTextTurn(String text, {required int streamIndex}) {
    textTurns.add(text);
  }
}

void main() {
  test('connect scopes the socket to the active note', () async {
    final socket = _FakeSocket();
    final session = NoteAiSession(socket: socket);

    await session.connect(
      const NoteAiSessionConfig(
        socketUrl: 'wss://socket.example',
        userId: '7',
        documentId: 4209,
      ),
    );

    expect(socket.headers, <String, String>{
      'X-User-Id': '7',
      'X-Client-App': 'nx_notes',
      'X-Agent-Id': 'nx_notes',
      'X-Document-Id': '4209',
    });
  });

  test('switching notes reconnects before the next turn', () async {
    final socket = _FakeSocket();
    final session = NoteAiSession(socket: socket);

    await session.connect(
      const NoteAiSessionConfig(
        socketUrl: 'wss://socket.example',
        userId: '7',
        documentId: 1,
      ),
    );
    await session.connect(
      const NoteAiSessionConfig(
        socketUrl: 'wss://socket.example',
        userId: '7',
        documentId: 2,
      ),
    );

    expect(socket.disconnects, 1);
    expect(socket.headers?['X-Document-Id'], '2');
  });

  test('text and audio turns share the note-scoped connection', () async {
    final socket = _FakeSocket();
    final session = NoteAiSession(socket: socket);
    await session.connect(
      const NoteAiSessionConfig(
        socketUrl: 'wss://socket.example',
        userId: '7',
        documentId: 42,
      ),
    );

    session.sendTextTurn('  explain this  ');
    session.beginAudioTurn();
    session.sendAudioPacket(Uint8List.fromList(<int>[1, 2, 3]));
    session.endAudioTurn();

    expect(socket.textTurns, <String>['explain this']);
    expect(socket.audioPackets, hasLength(1));
    expect(socket.audioEofs, 1);
  });
}
