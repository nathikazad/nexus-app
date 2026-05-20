# nx_voice

Shared Nexus voice utilities for Flutter apps.

## What It Provides

- WebSocket client for `new_server` voice/text packets.
- Packet codec matching `new_server.gateway.packets`.
- Microphone PCM16 capture with Opus encoding.
- Opus decode and PCM-to-WAV playback helper.

Audio defaults to 16 kHz mono PCM16 / 60 ms Opus frames. The 60 ms frame size keeps each decoded PCM chunk within AssemblyAI's streaming input duration limits.

## Basic Socket Use

```dart
final socket = NxVoiceSocketClient();

await socket.connect(
  'ws://localhost:8002/ws',
  headers: {
    'X-Client-App': 'nx_time',
  },
);

socket.sendTextTurn('What should I focus on next?');
```

## Microphone to Socket

```dart
final mic = NxMicrophoneOpusStreamer();
var packetIndex = 0;

await mic.start(
  onOpusPacket: (opus) {
    socket.sendAudioChunk(
      opus,
      streamIndex: 0,
      packetIndex: packetIndex++,
    );
  },
);

final remaining = await mic.stop();
for (final opus in remaining) {
  socket.sendAudioChunk(
    opus,
    streamIndex: 0,
    packetIndex: packetIndex++,
  );
}
socket.sendAudioEof(streamIndex: 0);
```

## Receiving

```dart
final player = NxWavAudioPlayer();

socket.onTextChunk = (packet) {
  print(packet.text);
};

socket.onAudioChunk = (packet) {
  player.addOpusPacket(packet.opus);
};

socket.onAudioEof = (_) {
  player.flush();
};
```
