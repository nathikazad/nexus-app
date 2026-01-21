import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as socket_status;
import 'package:web_socket_channel/web_socket_channel.dart';

// =============================================================================
// SOCKET STATUS ENUM
// =============================================================================

enum SocketStatus { notConnected, connecting, connected, disconnected }

// =============================================================================
// PURE SOCKET - WebSocket wrapper with reconnection logic
// =============================================================================

abstract class ISocketListener {
  void onConnected();
  void onMessage(dynamic message);
  void onClosed([int? closeCode]);
  void onError(Object err, StackTrace trace);
  void onMaxRetriesReached();
}

class PureSocket {
  WebSocketChannel? _channel;
  SocketStatus _status = SocketStatus.notConnected;
  ISocketListener? _listener;
  int _retries = 0;
  Timer? _pingTimer;
  final String url;

  SocketStatus get status => _status;

  PureSocket(this.url);

  void setListener(ISocketListener listener) {
    _listener = listener;
  }

  Future<bool> connect() async {
    if (_status == SocketStatus.connecting || _status == SocketStatus.connected) {
      return false;
    }

    debugPrint("[Socket] Connecting to $url");
    _status = SocketStatus.connecting;

    try {
      _channel = IOWebSocketChannel.connect(
        url,
        pingInterval: const Duration(seconds: 20),
        connectTimeout: const Duration(seconds: 15),
      );

      await _channel!.ready;
      _status = SocketStatus.connected;
      _retries = 0;
      debugPrint("[Socket] Connected successfully");
      _listener?.onConnected();

      // Start ping timer to keep connection alive
      _startPingTimer();

      // Listen for messages
      _channel!.stream.listen(
        (message) {
          if (message == "ping") {
            // Respond to server ping with pong
            _channel?.sink.add("pong");
            return;
          }
          _listener?.onMessage(message);
        },
        onError: (err, trace) {
          debugPrint("[Socket] Error: $err");
          _listener?.onError(err, trace);
          _status = SocketStatus.disconnected;
        },
        onDone: () {
          debugPrint("[Socket] Connection closed with code: ${_channel?.closeCode}");
          _stopPingTimer();
          _listener?.onClosed(_channel?.closeCode);
          _status = SocketStatus.disconnected;
        },
        cancelOnError: true,
      );

      return true;
    } on TimeoutException catch (e) {
      debugPrint("[Socket] Connection timeout: $e");
      _status = SocketStatus.notConnected;
      return false;
    } on SocketException catch (e) {
      debugPrint("[Socket] Socket exception: $e");
      _status = SocketStatus.notConnected;
      return false;
    } on WebSocketChannelException catch (e) {
      debugPrint("[Socket] WebSocket exception: $e");
      _status = SocketStatus.notConnected;
      return false;
    } catch (e) {
      debugPrint("[Socket] Connection error: $e");
      _status = SocketStatus.notConnected;
      return false;
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_status == SocketStatus.connected) {
        debugPrint("[Socket] Sending ping");
        send("ping");
      }
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<void> disconnect() async {
    _stopPingTimer();
    if (_status == SocketStatus.connected) {
      await _channel?.sink.close(socket_status.normalClosure);
    }
    _status = SocketStatus.disconnected;
    debugPrint("[Socket] Disconnected");
  }

  void send(dynamic message) {
    if (_status == SocketStatus.connected) {
      _channel?.sink.add(message);
    }
  }

  Future<void> reconnect() async {
    const int maxRetries = 8;
    const int initialBackoffMs = 1000;
    const double multiplier = 1.5;

    if (_status == SocketStatus.connecting || _status == SocketStatus.connected) {
      debugPrint("[Socket] Cannot reconnect, status is $_status");
      return;
    }

    debugPrint("[Socket] Reconnecting... attempt ${_retries + 1}");

    _stopPingTimer();

    bool ok = await connect();
    if (ok) {
      return;
    }

    // Calculate backoff delay
    int waitMs = pow(multiplier, _retries).toInt() * initialBackoffMs;
    await Future.delayed(Duration(milliseconds: waitMs));

    _retries++;
    if (_retries > maxRetries) {
      debugPrint("[Socket] Max retries ($maxRetries) reached");
      _listener?.onMaxRetriesReached();
      return;
    }

    // Recursive reconnection
    reconnect();
  }

  void dispose() {
    _stopPingTimer();
    _channel?.sink.close();
  }
}

// =============================================================================
// BACKGROUND SERVICE HANDLERS
// =============================================================================

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  PureSocket? socket;

  // Handle socket.connect command from UI
  service.on('socket.connect').listen((event) async {
    debugPrint("[BG] Received socket.connect command");
    socket = PureSocket('ws://192.168.0.44:8080');
    socket!.setListener(_BackgroundSocketListener(service));

    bool connected = await socket!.connect();
    service.invoke('socket.status', {'status': connected ? 'connected' : 'failed'});
  });

  // Handle socket.disconnect command from UI
  service.on('socket.disconnect').listen((event) async {
    debugPrint("[BG] Received socket.disconnect command");
    await socket?.disconnect();
    socket = null;
    service.invoke('socket.status', {'status': 'disconnected'});
  });

  // Handle socket.send command from UI
  service.on('socket.send').listen((event) async {
    final message = event?['message'];
    if (message != null && socket != null) {
      debugPrint("[BG] Sending message: $message");
      socket!.send(message);
    }
  });

  // Handle stop command
  service.on('stop').listen((event) async {
    await socket?.disconnect();
    service.stopSelf();
  });

  // Watchdog timer - keep service alive with heartbeat
  var pongAt = DateTime.now();
  service.on('pong').listen((event) async {
    pongAt = DateTime.now();
  });

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (pongAt.isBefore(DateTime.now().subtract(const Duration(seconds: 15)))) {
      // No pong received from UI for 15 seconds, stop service
      debugPrint("[BG] No heartbeat from UI, stopping service");
      await socket?.disconnect();
      service.stopSelf();
      return;
    }
    service.invoke("ui.ping");
  });
}

class _BackgroundSocketListener implements ISocketListener {
  final ServiceInstance _service;

  _BackgroundSocketListener(this._service);

  @override
  void onConnected() {
    debugPrint("[BG Socket] Connected");
    _service.invoke('socket.status', {'status': 'connected'});
  }

  @override
  void onMessage(dynamic message) {
    debugPrint("[BG Socket] Message received: $message");
    _service.invoke('socket.message', {'message': message.toString()});
  }

  @override
  void onClosed([int? closeCode]) {
    debugPrint("[BG Socket] Closed with code: $closeCode");
    _service.invoke('socket.status', {'status': 'disconnected', 'closeCode': closeCode});
  }

  @override
  void onError(Object err, StackTrace trace) {
    debugPrint("[BG Socket] Error: $err");
    _service.invoke('socket.error', {'error': err.toString()});
  }

  @override
  void onMaxRetriesReached() {
    debugPrint("[BG Socket] Max retries reached");
    _service.invoke('socket.status', {'status': 'max_retries_reached'});
  }
}

// =============================================================================
// BACKGROUND SERVICE MANAGER
// =============================================================================

class BackgroundSocketService {
  late FlutterBackgroundService _service;
  bool _isInitialized = false;

  final StreamController<String> _statusController = StreamController<String>.broadcast();
  final StreamController<String> _messageController = StreamController<String>.broadcast();

  Stream<String> get statusStream => _statusController.stream;
  Stream<String> get messageStream => _messageController.stream;

  Future<void> init() async {
    if (_isInitialized) return;

    _service = FlutterBackgroundService();

    await _service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        autoStart: false,
        onStart: onStart,
        isForegroundMode: true,
        autoStartOnBoot: false,
      ),
    );

    _isInitialized = true;
  }

  Future<void> start() async {
    await _service.startService();

    // Listen for status updates from background
    _service.on('socket.status').listen((event) {
      final status = event?['status'] ?? 'unknown';
      debugPrint("[UI] Socket status: $status");
      _statusController.add(status);
    });

    // Listen for messages from background
    _service.on('socket.message').listen((event) {
      final message = event?['message'] ?? '';
      debugPrint("[UI] Socket message: $message");
      _messageController.add(message);
    });

    // Listen for errors from background
    _service.on('socket.error').listen((event) {
      final error = event?['error'] ?? 'Unknown error';
      debugPrint("[UI] Socket error: $error");
      _statusController.add('error: $error');
    });

    // Heartbeat - respond to pings from background service
    _service.on('ui.ping').listen((event) {
      _service.invoke("pong");
    });
  }

  void connect() {
    _service.invoke('socket.connect');
  }

  void disconnect() {
    _service.invoke('socket.disconnect');
  }

  void sendMessage(String message) {
    _service.invoke('socket.send', {'message': message});
  }

  void stop() {
    _service.invoke('stop');
  }

  void dispose() {
    _statusController.close();
    _messageController.close();
  }
}

// =============================================================================
// MAIN APP
// =============================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BackgroundSocketApp());
}

class BackgroundSocketApp extends StatelessWidget {
  const BackgroundSocketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Background Socket Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SocketTestScreen(),
    );
  }
}

class SocketTestScreen extends StatefulWidget {
  const SocketTestScreen({super.key});

  @override
  State<SocketTestScreen> createState() => _SocketTestScreenState();
}

class _SocketTestScreenState extends State<SocketTestScreen> {
  final BackgroundSocketService _bgService = BackgroundSocketService();
  final TextEditingController _messageController = TextEditingController();
  final List<String> _log = [];
  String _status = 'not_connected';
  bool _isServiceRunning = false;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    await _bgService.init();

    _bgService.statusStream.listen((status) {
      setState(() {
        _status = status;
        _log.insert(0, '[STATUS] $status');
      });
    });

    _bgService.messageStream.listen((message) {
      setState(() {
        _log.insert(0, '[RECV] $message');
      });
    });
  }

  Future<void> _startService() async {
    await _bgService.start();
    setState(() {
      _isServiceRunning = true;
      _log.insert(0, '[INFO] Background service started');
    });
  }

  void _connect() {
    _bgService.connect();
    setState(() {
      _log.insert(0, '[INFO] Connecting...');
    });
  }

  void _disconnect() {
    _bgService.disconnect();
    setState(() {
      _log.insert(0, '[INFO] Disconnecting...');
    });
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      _bgService.sendMessage(message);
      setState(() {
        _log.insert(0, '[SEND] $message');
      });
      _messageController.clear();
    }
  }

  void _stopService() {
    _bgService.stop();
    setState(() {
      _isServiceRunning = false;
      _status = 'not_connected';
      _log.insert(0, '[INFO] Background service stopped');
    });
  }

  Color _getStatusColor() {
    switch (_status) {
      case 'connected':
        return Colors.green;
      case 'connecting':
        return Colors.orange;
      case 'disconnected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _bgService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Socket Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getStatusColor(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Status: $_status',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Server: ws://192.168.0.44:8080',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Service: ${_isServiceRunning ? "Running" : "Stopped"}',
                      style: TextStyle(
                        color: _isServiceRunning ? Colors.green : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isServiceRunning ? null : _startService,
                    child: const Text('Start Service'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: !_isServiceRunning ? null : _stopService,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[100],
                    ),
                    child: const Text('Stop Service'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isServiceRunning && _status != 'connected' ? _connect : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[100],
                    ),
                    child: const Text('Connect'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _status == 'connected' ? _disconnect : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[100],
                    ),
                    child: const Text('Disconnect'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Message Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Enter message to send',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _status == 'connected' ? _sendMessage : null,
                  child: const Text('Send'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Log Section
            const Text(
              'Message Log:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _log.length,
                  itemBuilder: (context, index) {
                    final entry = _log[index];
                    Color textColor = Colors.black;
                    if (entry.startsWith('[RECV]')) {
                      textColor = Colors.blue;
                    } else if (entry.startsWith('[SEND]')) {
                      textColor = Colors.green;
                    } else if (entry.startsWith('[STATUS]')) {
                      textColor = Colors.orange;
                    } else if (entry.startsWith('[INFO]')) {
                      textColor = Colors.grey;
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        entry,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: textColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

