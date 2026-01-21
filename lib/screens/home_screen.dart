import 'package:flutter/material.dart';
import 'voice_assistant_screen.dart';
import 'hardware_screen.dart';
import 'navigator_screen.dart';
import 'log_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _openVoiceAssistant() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VoiceAssistantScreen(),
        fullscreenDialog: true,
      ),
    );
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
