import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
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
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  
  bool _isRecording = false;
  bool _isConnected = false;
  bool _isTyping = false;
  bool _opusMode = false;
  String _currentTranscript = '';
  String? _currentlyPlayingAudio;
  
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
        final audioFilePath = await _audioService.stopRecording();
        await _audioSubscription?.cancel();
        
        // If we have a transcript, add it as a user message
        if (_currentTranscript.isNotEmpty) {
          setState(() {
            _messages.add(ChatMessage(
              text: _currentTranscript,
              isFromUser: true,
              timestamp: DateTime.now(),
              audioFilePath: audioFilePath,
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

  void _toggleOpusMode() {
    setState(() {
      _opusMode = !_opusMode;
    });
    // Update the audio service with the new Opus mode
    _audioService.setOpusMode(_opusMode);
  }

  Future<void> _playAudio(String filePath) async {
    try {
      if (_currentlyPlayingAudio == filePath) {
        // If the same audio is playing, stop it
        await _audioPlayer.stop();
        setState(() {
          _currentlyPlayingAudio = null;
        });
      } else {
        // Stop any currently playing audio
        await _audioPlayer.stop();
        
        // Play the new audio - handle both file paths and blob URLs
        if (kIsWeb && filePath.startsWith('blob:')) {
          // For web blob URLs
          await _audioPlayer.play(UrlSource(filePath));
        } else {
          // For mobile file paths
          await _audioPlayer.play(DeviceFileSource(filePath));
        }
        
        setState(() {
          _currentlyPlayingAudio = filePath;
        });
        
        // Listen for completion
        _audioPlayer.onPlayerComplete.listen((_) {
          setState(() {
            _currentlyPlayingAudio = null;
          });
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to play audio: $e');
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
    _audioPlayer.dispose();
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
                return _MessageBubble(
                  message: message,
                  onPlayAudio: message.audioFilePath != null 
                    ? () => _playAudio(message.audioFilePath!)
                    : null,
                  isPlaying: _currentlyPlayingAudio == message.audioFilePath,
                );
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
                  if (_opusMode) ...[
                    const Icon(Icons.compress, color: Colors.blue, size: 16),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      _currentTranscript.isEmpty 
                        ? 'Recording${_opusMode ? ' (Opus)' : ''}...' 
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
                
                // Opus mode toggle button
                IconButton(
                  onPressed: _isConnected ? _toggleOpusMode : null,
                  icon: Icon(_opusMode ? Icons.compress : Icons.compress_outlined),
                  style: IconButton.styleFrom(
                    backgroundColor: _opusMode ? Theme.of(context).primaryColor : Colors.grey[300],
                    foregroundColor: _opusMode ? Colors.white : Colors.black,
                  ),
                  tooltip: _opusMode ? 'Disable Opus compression' : 'Enable Opus compression',
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
  final String? audioFilePath;
  
  ChatMessage({
    required this.text,
    required this.isFromUser,
    required this.timestamp,
    this.audioFilePath,
  });
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onPlayAudio;
  final bool isPlaying;
  
  const _MessageBubble({
    required this.message,
    this.onPlayAudio,
    this.isPlaying = false,
  });
  
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
            child: Column(
              crossAxisAlignment: message.isFromUser 
                ? CrossAxisAlignment.end 
                : CrossAxisAlignment.start,
              children: [
                Container(
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
                // Add playback button if audio file exists
                if (message.audioFilePath != null && message.isFromUser) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onPlayAudio,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPlaying ? Icons.stop : Icons.play_arrow,
                            size: 16,
                            color: Colors.black87,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPlaying ? 'Stop' : 'Play',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
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