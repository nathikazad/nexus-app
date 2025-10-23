import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/audio_service.dart';
import '../services/openai_service.dart';
import '../services/audio_stream_manager.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  final AudioService _audioService = AudioService();
  final OpenAIService _openAIService = OpenAIService();
  final AudioStreamManager _audioStreamManager = AudioStreamManager();
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
  StreamSubscription<Map<String, dynamic>>? _conversationSubscription;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupAudioStreamManager();
  }

  void _setupAudioStreamManager() {
    _audioStreamManager.onPlaybackStateChanged = (isPlaying) {
      setState(() {
        // Update UI state based on audio playback
      });
    };
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
        String type = data['type']!;
        
        if (type == 'transcript') {
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
        } else if (type == 'audio' && speaker == 'AI') {
          // Handle streamed audio from AI
          Uint8List audioData = data['audio']!;
          _audioStreamManager.playStreamedAudio(audioData);
        }
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
        
        // Use the audio stream manager for consistent audio handling
        await _audioStreamManager.playAudio(filePath);
        
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
    _audioStreamManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _VoiceAssistantAppBar(
        isConnected: _isConnected,
        isPlayingStreamedAudio: _audioStreamManager.isPlayingStreamedAudio,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _MessagesList(
              messages: _messages,
              isTyping: _isTyping,
              scrollController: _scrollController,
              onPlayAudio: _playAudio,
              currentlyPlayingAudio: _currentlyPlayingAudio,
            ),
          ),
          
          // Recording indicator
          if (_isRecording)
            _RecordingIndicator(
              currentTranscript: _currentTranscript,
              opusMode: _opusMode,
            ),
          
          // Input area
          _InputArea(
            isConnected: _isConnected,
            isRecording: _isRecording,
            opusMode: _opusMode,
            textController: _textController,
            onToggleRecording: _toggleRecording,
            onToggleOpusMode: _toggleOpusMode,
            onSendTextMessage: _sendTextMessage,
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

class _VoiceAssistantAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isConnected;
  final bool isPlayingStreamedAudio;

  const _VoiceAssistantAppBar({
    required this.isConnected,
    required this.isPlayingStreamedAudio,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Voice Assistant'),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              // Streamed audio indicator
              if (isPlayingStreamedAudio) ...[
                const Icon(Icons.volume_up, color: Colors.blue, size: 16),
                const SizedBox(width: 4),
              ],
              Icon(
                isConnected ? Icons.wifi : Icons.wifi_off,
                color: isConnected ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                isConnected ? 'Connected' : 'Disconnected',
                style: TextStyle(
                  color: isConnected ? Colors.green : Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _MessagesList extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool isTyping;
  final ScrollController scrollController;
  final Function(String) onPlayAudio;
  final String? currentlyPlayingAudio;

  const _MessagesList({
    required this.messages,
    required this.isTyping,
    required this.scrollController,
    required this.onPlayAudio,
    required this.currentlyPlayingAudio,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length && isTyping) {
          return const _TypingIndicator();
        }
        
        final message = messages[index];
        return _MessageBubble(
          message: message,
          onPlayAudio: message.audioFilePath != null 
            ? () => onPlayAudio(message.audioFilePath!)
            : null,
          isPlaying: currentlyPlayingAudio == message.audioFilePath,
        );
      },
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  final String currentTranscript;
  final bool opusMode;

  const _RecordingIndicator({
    required this.currentTranscript,
    required this.opusMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.red.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.red),
          const SizedBox(width: 8),
          if (opusMode) ...[
            const Icon(Icons.compress, color: Colors.blue, size: 16),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              currentTranscript.isEmpty 
                ? 'Recording${opusMode ? ' (Opus)' : ''}...' 
                : 'You said: $currentTranscript',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputArea extends StatelessWidget {
  final bool isConnected;
  final bool isRecording;
  final bool opusMode;
  final TextEditingController textController;
  final VoidCallback onToggleRecording;
  final VoidCallback onToggleOpusMode;
  final VoidCallback onSendTextMessage;

  const _InputArea({
    required this.isConnected,
    required this.isRecording,
    required this.opusMode,
    required this.textController,
    required this.onToggleRecording,
    required this.onToggleOpusMode,
    required this.onSendTextMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            onPressed: isConnected ? onToggleRecording : null,
            icon: Icon(isRecording ? Icons.stop : Icons.mic),
            style: IconButton.styleFrom(
              backgroundColor: isRecording ? Colors.red : Colors.grey[300],
              foregroundColor: isRecording ? Colors.white : Colors.black,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Opus mode toggle button
          IconButton(
            onPressed: isConnected ? onToggleOpusMode : null,
            icon: Icon(opusMode ? Icons.compress : Icons.compress_outlined),
            style: IconButton.styleFrom(
              backgroundColor: opusMode ? Theme.of(context).primaryColor : Colors.grey[300],
              foregroundColor: opusMode ? Colors.white : Colors.black,
            ),
            tooltip: opusMode ? 'Disable Opus compression' : 'Enable Opus compression',
          ),
          
          const SizedBox(width: 8),
          
          // Text input field
          Expanded(
            child: TextField(
              controller: textController,
              enabled: isConnected,
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
              onSubmitted: (_) => onSendTextMessage(),
              textInputAction: TextInputAction.send,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Send button
          IconButton(
            onPressed: isConnected ? onSendTextMessage : null,
            icon: const Icon(Icons.send),
            style: IconButton.styleFrom(
              backgroundColor: isConnected ? Theme.of(context).primaryColor : Colors.grey[300],
              foregroundColor: isConnected ? Colors.white : Colors.grey[600],
            ),
          ),
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