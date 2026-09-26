import 'dart:typed_data';

enum SocketConnectionState { disconnected, connecting, connected }

enum SocketSendStatus { sent, queuedNoConnection, queuedAfterSendFailure }

/// Relay-facing transport contract. Connection authentication and queue storage
/// remain owned by the concrete socket transport.
abstract interface class NecklaceSocketPort {
  bool get isConnected;
  SocketConnectionState get connectionState;
  int get queuedPacketCount;
  Future<bool> ensureConnected({String reason = 'ensureConnected'});
  SocketSendStatus sendPacket(Uint8List data, {int? index});
  void sendImagePacket(Uint8List data, int index);
  void clearQueue();
  set onPacketFromServer(Future<void> Function(Uint8List)? callback);
  set onAudioReceptionSummary(void Function(Map<String, dynamic>)? callback);
  set onDeviceRequest(
      Future<String?> Function(int, String, Map<String, dynamic>)? callback);
}
