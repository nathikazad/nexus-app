import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'voice_assistant_screen.dart';
import 'hardware_screen.dart';
import 'navigator_screen.dart';
import 'log_viewer_screen.dart';
import '../services/watch_bridge_service.dart';
import '../services/ai_service/openai_service.dart';

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
    
    // Listen for audio packets from watch - send to OpenAI
    _watchAudioSubscription = WatchBridgeService.instance.audioStream.listen((packet) {
      final openAIService = ref.read(openAIServiceProvider);
      openAIService.sendAudio(packet.data, queryOrigin.Watch);
    });
    
    // Listen for EOF from watch - trigger OpenAI response
    _watchEOFSubscription = WatchBridgeService.instance.eofStream.listen((eof) {
      print('[HomeScreen] 🏁 Watch EOF received, calling createResponse()');
      final openAIService = ref.read(openAIServiceProvider);
      openAIService.createResponse();
    });
  }

  @override
  void dispose() {
    _watchMessageSubscription?.cancel();
    _watchAudioSubscription?.cancel();
    _watchEOFSubscription?.cancel();
    super.dispose();
  }

  void _openVoiceAssistant() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VoiceAssistantScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _testPing() async {
    final result = await WatchBridgeService.instance.ping();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ping response: ${result ?? "failed"}'),
          backgroundColor: result != null ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Platform.isIOS ? AppBar(
        title: const Text('Nexus'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Test Ping',
            onPressed: _testPing,
          ),
        ],
      ) : null,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HardwareScreen(),
          NavigatorHomeScreen(),
          LogViewerScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.devices),
            label: 'Hardware',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.navigation),
            label: 'Navigator',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Logs',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openVoiceAssistant,
        child: const Icon(Icons.chat),
        tooltip: 'Voice Assistant',
      ),
    );
  }
}
