import 'package:web_socket_channel/web_socket_channel.dart';

import 'realtime_websocket_connector_stub.dart'
    if (dart.library.io) 'realtime_websocket_connector_io.dart'
    as platform;

Future<WebSocketChannel> connectRealtimeWebSocket({
  required Uri uri,
  required String credential,
}) => platform.connectRealtimeWebSocket(uri: uri, credential: credential);
