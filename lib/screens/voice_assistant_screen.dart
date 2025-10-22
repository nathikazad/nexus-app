import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/audio_service.dart';
import '../services/openai_service.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  final AudioService _audioService = AudioService();
  final OpenAIService _openAIService = OpenAIService();
  
  bool _isRecording = false;
  bool _isConnected = false;
  String _status = 'Not connected';
  String _conversation = '';
  String _currentSpeaker = '';
  String _currentMessage = '';
  
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<Map<String, String>>? _conversationSubscription;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _setupSubscriptions();
  }

  void _setupSubscriptions() {
    _conversationSubscription = _openAIService.conversationStream.listen((data) {
      String speaker = data['speaker']!;
      String word = data['word']!;
      
      setState(() {
        // If speaker changed, finalize the previous message and start a new one
        if (_currentSpeaker != speaker && _currentSpeaker.isNotEmpty) {
          String speakerIcon = _currentSpeaker == 'AI' ? '🤖 AI' : '👤 You';
          _conversation += '$speakerIcon: $_currentMessage\n';
          _currentMessage = word;
        } else {
          // Same speaker, append to current message
          _currentMessage += word;
        }
        _currentSpeaker = speaker;
      });
      
      // Auto-scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  Future<void> _connectToOpenAI() async {
    setState(() {
      _status = 'Connecting...';
    });

    final initialized = await _openAIService.initialize();

    if (!initialized) {
      setState(() {
        _status = 'Failed to initialize';
      });
      _showSnackBar('Failed to initialize OpenAI service');
      return;
    }

    final connected = await _openAIService.connect();
    
    setState(() {
      _isConnected = connected;
      _status = connected ? 'Connected' : 'Connection failed';
    });

    if (connected) {
      _showSnackBar('Connected to OpenAI Realtime API');
    } else {
      _showSnackBar('Failed to connect to OpenAI');
    }
  }

  Future<void> _startRecording() async {
    if (!_isConnected) {
      _showSnackBar('Please connect to OpenAI first');
      return;
    }

    final started = await _audioService.startRecording();
    if (started) {
      setState(() {
        _isRecording = true;
      });

      // Listen to audio stream and send to OpenAI
      _audioSubscription = _audioService.audioStream?.listen((audioData) {
        _openAIService.sendAudio(audioData);
      });

      _showSnackBar('Recording started');
    } else {
      _showSnackBar('Failed to start recording. Check microphone permissions or try on a physical device (iOS Simulator has audio limitations).');
      setState(() {
        _status = 'Recording failed';
      });
    }
  }

  Future<void> _stopRecording() async {
    await _audioService.stopRecording();
    await _audioSubscription?.cancel();
    
    setState(() {
      _isRecording = false;
    });

    _showSnackBar('Recording stopped');
  }

  void _clearConversation() {
    setState(() {
      _conversation = '';
      _currentSpeaker = '';
      _currentMessage = '';
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _conversationSubscription?.cancel();
    _scrollController.dispose();
    _audioService.dispose();
    _openAIService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nexus Voice Assistant'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _clearConversation,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear conversation',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status and Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OpenAI Connection',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isConnected ? null : _connectToOpenAI,
                      child: Text(_isConnected ? 'Connected' : 'Connect to OpenAI'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      _isConnected ? Icons.check_circle : Icons.error,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text('Status: $_status'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Recording Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Voice Recording',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        FloatingActionButton(
                          onPressed: _isRecording ? null : _startRecording,
                          backgroundColor: Colors.green,
                          child: const Icon(Icons.mic),
                        ),
                        FloatingActionButton(
                          onPressed: _isRecording ? _stopRecording : null,
                          backgroundColor: Colors.red,
                          child: const Icon(Icons.stop),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isRecording ? 'Recording...' : 'Tap mic to start recording',
                      style: TextStyle(
                        color: _isRecording ? Colors.red : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Conversation Transcript
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.chat, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Conversation',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: Text(
                            _conversation.isEmpty ? 'No conversation yet...\n\nTap the microphone to start talking!' : _conversation,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}