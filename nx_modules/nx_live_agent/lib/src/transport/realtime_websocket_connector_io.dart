import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connectRealtimeWebSocket({
  required Uri uri,
  required String credential,
}) async {
  final channel = IOWebSocketChannel.connect(
    uri,
    headers: <String, String>{'Authorization': 'Bearer $credential'},
    pingInterval: const Duration(seconds: 20),
  );
  await channel.ready;
  return channel;
}
