import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connectRealtimeWebSocket({
  required Uri uri,
  required String credential,
}) => throw UnsupportedError(
  'The authenticated Realtime WebSocket transport is unavailable here.',
);
