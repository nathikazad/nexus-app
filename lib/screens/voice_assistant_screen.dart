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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  
  bool _isRecording = false;
  bool _isConnected = false;
  bool _isTyping = false;
  String _currentTranscript = '';
  
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<Map<String, String>>? _conversationSubscription;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _openAIService.initialize();
      await _openAIService.connect();
      setState(() {
        _isConnected = true;
      });
      
      // Listen to conversation stream
      _conversationSubscription = _openAIService.conversationStream.listen((data) {
        String speaker = data['speaker']!;
        String word = data['word']!;
        
        setState(() {
          if (speaker == 'AI') {
            // Update or create AI message
            if (_messages.isNotEmpty && _messages.last.isFromUser == false) {
              // Update the last assistant message
              final lastMessage = _messages.removeLast();
              _messages.add(ChatMessage(
                text: lastMessage.text + word,
                isFromUser: false,
                timestamp: lastMessage.timestamp,
              ));
            } else {
              // Create new assistant message
              _messages.add(ChatMessage(
                text: word,
                isFromUser: false,
                timestamp: DateTime.now(),
              ));
            }
          } else {
            // Update current transcript for user
            _currentTranscript += word;
          }
        });
        _scrollToBottom();
      });
      
    } catch (e) {
      _showErrorDialog('Failed to connect to OpenAI: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleRecording() async {
    if (!_isConnected) {
      _showErrorDialog('Not connected to OpenAI service');
      return;
    }
    
    try {
      if (_isRecording) {
        await _audioService.stopRecording();
        await _audioSubscription?.cancel();
        
        // If we have a transcript, add it as a user message
        if (_currentTranscript.isNotEmpty) {
          setState(() {
            _messages.add(ChatMessage(
              text: _currentTranscript,
              isFromUser: true,
              timestamp: DateTime.now(),
            ));
          });
          _scrollToBottom();
        }
        
        setState(() {
          _isRecording = false;
          _currentTranscript = '';
        });
      } else {
        final started = await _audioService.startRecording();
        if (started) {
          setState(() {
            _isRecording = true;
            _currentTranscript = '';
          });

          // Listen to audio stream and send to OpenAI
          _audioSubscription = _audioService.audioStream?.listen((audioData) {
            _openAIService.sendAudio(audioData);
          });
        } else {
          _showErrorDialog('Failed to start recording. Check microphone permissions.');
        }
      }
    } catch (e) {
      _showErrorDialog('Failed to toggle recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || !_isConnected) {
      return;
    }

    // Add user message to chat
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isFromUser: true,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();

    // Clear text field
    _textController.clear();

    // Send to OpenAI
    try {
      await _openAIService.sendTextMessage(text);
    } catch (e) {
      _showErrorDialog('Failed to send message: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _conversationSubscription?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    _audioService.dispose();
    _openAIService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Assistant'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.wifi : Icons.wifi_off,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? 'Connecteds' : 'Disconnected',
                  style: TextStyle(
                    color: _isConnected ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return const _TypingIndicator();
                }
                
                final message = _messages[index];
                return _MessageBubble(message: message);
              },
            ),
          ),
          
          // Recording indicator
          if (_isRecording)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentTranscript.isEmpty 
                        ? 'Recording...' 
                        : 'You said: $_currentTranscript',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          
          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Voice recording button
                IconButton(
                  onPressed: _isConnected ? _toggleRecording : null,
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                  style: IconButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red : Colors.grey[300],
                    foregroundColor: _isRecording ? Colors.white : Colors.black,
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Text input field
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: _isConnected,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Theme.of(context).primaryColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendTextMessage(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Send button
                IconButton(
                  onPressed: _isConnected ? _sendTextMessage : null,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: _isConnected ? Theme.of(context).primaryColor : Colors.grey[300],
                    foregroundColor: _isConnected ? Colors.white : Colors.grey[600],
                  ),
                ),
                
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isFromUser;
  final DateTime timestamp;
  
  ChatMessage({
    required this.text,
    required this.isFromUser,
    required this.timestamp,
  });
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  
  const _MessageBubble({required this.message});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isFromUser 
          ? MainAxisAlignment.end 
          : MainAxisAlignment.start,
        children: [
          if (!message.isFromUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isFromUser
                  ? Theme.of(context).primaryColor
                  : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isFromUser ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
          if (message.isFromUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).primaryColor,
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('AI is typing...'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}