import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'hardware_screen.dart';
import 'navigator_screen.dart';
import 'log_viewer_screen.dart';
import 'data_screen.dart';
import '../services/watch_bridge_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  StreamSubscription<String>? _watchMessageSubscription;
  StreamSubscription<WatchAudioPacket>? _watchAudioSubscription;
  StreamSubscription<WatchAudioEOF>? _watchEOFSubscription;

  @override
  void initState() {
    super.initState();
    _setupWatchListeners();
  }

  void _setupWatchListeners() {
    if (!Platform.isIOS) return;
    
    // Listen for text messages from watch
    _watchMessageSubscription = WatchBridgeService.instance.messageStream.listen((message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('From Watch: $message'),
            backgroundColor: Colors.deepPurple,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
    
    // // Listen for audio packets from watch - send to OpenAI
    // _watchAudioSubscription = WatchBridgeService.instance.audioStream.listen((packet) {
    //   final openAIService = ref.read(openAIServiceProvider);
    //   openAIService.sendAudio(packet.data, queryOrigin.Watch);
    // });
    
    // // Listen for EOF from watch - trigger OpenAI response
    // _watchEOFSubscription = WatchBridgeService.instance.eofStream.listen((eof) {
    //   print('[HomeScreen] 🏁 Watch EOF received, calling createResponse()');
    //   final openAIService = ref.read(openAIServiceProvider);
    //   openAIService.createResponse();
    // });
  }

  @override
  void dispose() {
    _watchMessageSubscription?.cancel();
    _watchAudioSubscription?.cancel();
    _watchEOFSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HardwareScreen(),
          NavigatorHomeScreen(),
          LogViewerScreen(),
          DataScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          // Matches reference/shell/home-tab-shell.html (Lucide: cpu, layout-grid, terminal-square, database).
          BottomNavigationBarItem(
            icon: Icon(Icons.developer_board_rounded),
            label: 'Hardware',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_open_rounded),
            label: 'Navigator',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.terminal_rounded),
            label: 'Logs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.input_rounded),
            label: 'Data',
          ),
        ],
      ),
    );
  }
}
