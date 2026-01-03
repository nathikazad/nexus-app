import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/voice_assistant_screen.dart';
import 'services/ble_service.dart';
import 'services/openai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load();
  
  // Request microphone permission (only needed for mobile platforms)
  if (!kIsWeb) {
    await Permission.microphone.request();
  }
  
  // Initialize BLE service (only needed for mobile platforms)
  if (!kIsWeb) {
    await BLEService.instance.initialize();
  }
  
  // Initialize and connect OpenAI service
  await OpenAIService.instance.initialize();
  await OpenAIService.instance.connect();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexus Voice Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const VoiceAssistantScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
