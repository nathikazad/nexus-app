import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/audio_service.dart';
import '../services/openai_service.dart';
import '../widgets/audio_stream_manager.dart';
import '../widgets/message_bubble.dart';
import '../widgets/input_area.dart';

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
  bool _speakerEnabled = false;
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
          // Handle streamed audio from AI - only play if speaker is enabled
          if (_speakerEnabled) {
            Uint8List audioData = data['audio']!;
            _audioStreamManager.playStreamedAudio(audioData);
          }
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

  void _toggleSpeaker() {
    setState(() {
      _speakerEnabled = !_speakerEnabled;
    });

    // Update the audio stream manager with the new speaker state
    _audioStreamManager.setSpeakerEnabled(_speakerEnabled);

    // If speaker is being disabled, stop any currently playing audio
    if (!_speakerEnabled) {
      _audioPlayer.stop();
      setState(() {
        _currentlyPlayingAudio = null;
      });
    }
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
          InputArea(
            isConnected: _isConnected,
            isRecording: _isRecording,
            opusMode: _opusMode,
            speakerEnabled: _speakerEnabled,
            textController: _textController,
            onToggleRecording: _toggleRecording,
            onToggleOpusMode: _toggleOpusMode,
            onToggleSpeaker: _toggleSpeaker,
            onSendTextMessage: _sendTextMessage,
          ),
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
        return MessageBubble(
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