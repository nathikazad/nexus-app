import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/companion/note_ai_session.dart';
import 'package:nx_voice/nx_voice.dart';

class _FakeSocket implements NoteAiSocketPort {
  bool connected = false;
  int disconnects = 0;
  String? url;
  Map<String, String>? headers;
  Future<Map<String, String>> Function(bool forceRefresh)? authHeaders;
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
    required Future<Map<String, String>> Function(bool forceRefresh)
    authHeaders,
  }) async {
    connected = true;
    this.url = url;
    this.headers = headers;
    this.authHeaders = authHeaders;
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
  Future<Map<String, String>> bearer(bool forceRefresh) async => {
    'authorization': 'Bearer ${forceRefresh ? 'refreshed' : 'current'}',
  };

  test('connect scopes the socket to the active note', () async {
    final socket = _FakeSocket();
    final session = NoteAiSession(socket: socket);

    await session.connect(
      NoteAiSessionConfig(
        socketUrl: 'wss://socket.example',
        userId: '7',
        documentId: 4209,
        authHeaders: bearer,
      ),
    );

    expect(socket.headers, <String, String>{
      'X-Client-App': 'nx_notes',
      'X-Agent-Id': 'nx_notes',
      'X-Document-Id': '4209',
    });
    expect(await socket.authHeaders!(true), {
      'authorization': 'Bearer refreshed',
    });
  });

  test('switching notes reconnects before the next turn', () async {
    final socket = _FakeSocket();
    final session = NoteAiSession(socket: socket);

    await session.connect(
      NoteAiSessionConfig(
        socketUrl: 'wss://socket.example',
        userId: '7',
        documentId: 1,
        authHeaders: bearer,
      ),
    );
    await session.connect(
      NoteAiSessionConfig(
        socketUrl: 'wss://socket.example',
        userId: '7',
        documentId: 2,
        authHeaders: bearer,
      ),
    );

    expect(socket.disconnects, 1);
    expect(socket.headers?['X-Document-Id'], '2');
  });

  test('switching accounts reconnects with the new token provider', () async {
    final socket = _FakeSocket();
    final session = NoteAiSession(socket: socket);

    await session.connect(
      NoteAiSessionConfig(
        socketUrl: 'wss://socket.example',
        userId: '7',
        documentId: 1,
        authHeaders: (_) async => {
          'authorization': 'Bearer account-a',
        },
      ),
    );
    await session.connect(
      NoteAiSessionConfig(
        socketUrl: 'wss://socket.example',
        userId: '8',
        documentId: 1,
        authHeaders: (forceRefresh) async => {
          'authorization':
              'Bearer ${forceRefresh ? 'account-b-new' : 'account-b'}',
        },
      ),
    );

    expect(socket.disconnects, 1);
    expect(await socket.authHeaders!(false), {
      'authorization': 'Bearer account-b',
    });
    expect(await socket.authHeaders!(true), {
      'authorization': 'Bearer account-b-new',
    });
  });

  test('text and audio turns share the note-scoped connection', () async {
    final socket = _FakeSocket();
    final session = NoteAiSession(socket: socket);
    await session.connect(
      NoteAiSessionConfig(
        socketUrl: 'wss://socket.example',
        userId: '7',
        documentId: 42,
        authHeaders: bearer,
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
