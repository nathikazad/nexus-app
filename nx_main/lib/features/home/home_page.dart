import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/data/watch/watch_bridge_service.dart';
import 'package:nexus_voice_assistant/features/data_browser/data_page.dart';
import 'package:nexus_voice_assistant/features/hardware/hardware_page.dart';
import 'package:nexus_voice_assistant/features/logs/log_viewer_page.dart';
import 'package:nexus_voice_assistant/features/schema_navigator/models_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
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

    _watchMessageSubscription =
        WatchBridgeService.instance.messageStream.listen((message) {
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
          HardwarePage(),
          ModelsPage(),
          LogViewerPage(),
          DataPage(),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.developer_board_rounded),
            label: 'Hardware',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schema_rounded),
            label: 'Models',
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
