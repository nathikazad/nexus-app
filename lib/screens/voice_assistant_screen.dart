import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:nexus_voice_assistant/services/audio_service/audio_service.dart';
import 'package:nexus_voice_assistant/services/ai_service/openai_service.dart';
import 'package:nexus_voice_assistant/services/hardware_service/hardware_service.dart';
import 'package:nexus_voice_assistant/services/file_transfer_service/file_transfer_service.dart';
import 'package:nexus_voice_assistant/widgets/audio_stream_manager.dart';
import 'package:nexus_voice_assistant/widgets/message_bubble.dart';
import 'package:nexus_voice_assistant/widgets/input_area.dart';
import 'package:nexus_voice_assistant/services/logging_service.dart';

class VoiceAssistantScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSwitchToHardwareTab;
  
  const VoiceAssistantScreen({super.key, this.onSwitchToHardwareTab});

  @override
  ConsumerState<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends ConsumerState<VoiceAssistantScreen> {
  final AudioService _audioService = AudioService();
  late final OpenAIService _openAIService;
  final HardwareService _hardwareService = HardwareService.instance;
  final AudioStreamManager _audioStreamManager = AudioStreamManager();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  
  // Get interactions from the service
  List<Interaction> get _interactions => _openAIService.interactions;

  
  bool _isRecording = false;
  bool _isConnected = false;
  bool _isTyping = false;
  bool _speakerEnabled = false;
  String _currentTranscript = '';
  String? _currentlyPlayingAudio;
  // int _turnCount = 0;
  
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<Map<String, dynamic>>? _conversationSubscription;
  StreamSubscription<List<Interaction>>? _interactionsSubscription;
  StreamSubscription<bool>? _bleConnectionSubscription;

  @override
  void initState() {
    super.initState();
    // Get OpenAI service from provider
    _openAIService = ref.read(openAIServiceProvider);
    
    _initializeServices();
    _setupAudioStreamManager();
    _setupBLEConnectionListener();
  }
  
  void _setupBLEConnectionListener() {
    // Listen to BLE connection state changes (event-based, not polling)
    _bleConnectionSubscription = _hardwareService.connectionStateStream?.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    });
    
    // Set initial connection state
    setState(() {
      _isConnected = _hardwareService.isConnected;
    });
  }

  void _setupAudioStreamManager() {
    _audioStreamManager.onPlaybackStateChanged = (isPlaying) {
      setState(() {
        // Update UI state based on audio playback
      });
    };
  }
  // String currentSpeaker = '';
  Future<void> _initializeServices() async {
    try {
      // Initialize HardwareService (which initializes BLE service)
      await _hardwareService.initialize();
      
      // Listen to interactions stream from the service
      _interactionsSubscription = _openAIService.interactionsStream.listen((_) {
        if (mounted) {
          setState(() {});
          _scrollToBottom();
        }
      });
      
      // Listen to conversation stream for audio handling
      _conversationSubscription = _openAIService.conversationStream.listen((data) {
        String type = data['type']!;
        
        if (type == 'audio' && data['speaker'] == 'AI') {
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
  
  void _clearInteractions() {
    _openAIService.clearInteractions();
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
      _showErrorDialog('Not connected to Bluetooth device');
      return;
    }
    
    try {
      if (_isRecording) {
        await _audioService.stopRecording();
        await _audioSubscription?.cancel();
        
        // Commit audio buffer and request response (equivalent to Python lines 154-158)
        try {
          await _openAIService.createResponse();
        } catch (e) {
          LoggingService.instance.log('Error creating response after recording stop: $e');
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
            _openAIService.sendAudio(audioData, queryOrigin.App);
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

    String newLog = 'You: $text';
    print(newLog);

    // Update current interaction with user query and add to list
    setState(() {
      _interactions.last.addToUserQuery(text);
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
    _interactionsSubscription?.cancel();
    _bleConnectionSubscription?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    _audioPlayer.dispose();
    _audioService.dispose();
    _audioStreamManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Assistant'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear conversation',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Conversation'),
                  content: const Text('Are you sure you want to clear all messages?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        _clearInteractions();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _MessagesList(
              interactions: _interactions,
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
            ),
          
          // Input area
          InputArea(
            isConnected: _isConnected,
            isRecording: _isRecording,
            speakerEnabled: _speakerEnabled,
            textController: _textController,
            onToggleRecording: _toggleRecording,
            onToggleSpeaker: _toggleSpeaker,
            onSendTextMessage: _sendTextMessage,
          ),
        ],
      ),
      // floatingActionButton: Row(
      //   mainAxisAlignment: MainAxisAlignment.end,
      //   children: [
      //     FloatingActionButton(
      //       onPressed: _testLayer2,
      //       tooltip: 'Test Layer 2 (List Files)',
      //       child: const Icon(Icons.folder),
      //     ),
      //     const SizedBox(width: 10),
      //     FloatingActionButton(
      //       onPressed: _testLayer3,
      //       tooltip: 'Test Layer 3 (Receive File)',
      //       child: const Icon(Icons.download),
      //     ),
      //     const SizedBox(width: 10),
      //     FloatingActionButton(
      //       onPressed: _downloadRadioWav,
      //       tooltip: 'Download radio.wav',
      //       child: const Icon(Icons.radio),
      //     ),
      //   ],
      // ),
    );
  }
  
  Future<void> _testLayer2() async {
    LoggingService.instance.log('=== Layer 2 Test: Starting file list request ===');
    
    if (!_isConnected) {
      LoggingService.instance.log('Layer 2 Test: Not connected to Bluetooth device');
      _showErrorDialog('Not connected to Bluetooth device');
      return;
    }
    
    LoggingService.instance.log('Layer 2 Test: Device is connected');
    
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Request file list
      final files = await FileTransferService.instance.listFiles();
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show results dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Layer 2 Test - File List'),
          content: SizedBox(
            width: double.maxFinite,
            child: files.isEmpty
                ? const Text('No files found')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return ListTile(
                        leading: Icon(
                          file.isDirectory ? Icons.folder : Icons.insert_drive_file,
                        ),
                        title: Text(file.name),
                        subtitle: Text(
                          file.isDirectory 
                              ? 'Directory' 
                              : '${file.size} bytes',
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      
      LoggingService.instance.log('Layer 2 Test: Successfully completed');
    } catch (e, stackTrace) {
      LoggingService.instance.log('Layer 2 Test: ERROR - $e');
      LoggingService.instance.log('Layer 2 Test: Stack trace: $stackTrace');
      
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _showErrorDialog('Failed to list files: $e');
    }
    
    LoggingService.instance.log('=== Layer 2 Test: Finished ===');
  }
  
  Future<void> _testLayer3() async {
    LoggingService.instance.log('=== Layer 3 Test: Starting file receive (image1.jpg) ===');
    
    if (!_isConnected) {
      LoggingService.instance.log('Layer 3 Test: Not connected to Bluetooth device');
      _showErrorDialog('Not connected to Bluetooth device');
      return;
    }
    
    LoggingService.instance.log('Layer 3 Test: Device is connected');
    
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Request file
      final fileEntry = await FileTransferService.instance.requestFile('image1.jpg');
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show results dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Layer 3 Test - File Received'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: ${fileEntry.name}'),
                Text('Size: ${fileEntry.size} bytes'),
                const SizedBox(height: 16),
                // Show image if it's an image file and path is available
                if (fileEntry.path != null && 
                    (fileEntry.name.toLowerCase().endsWith('.jpg') ||
                     fileEntry.name.toLowerCase().endsWith('.jpeg') ||
                     fileEntry.name.toLowerCase().endsWith('.png') ||
                     fileEntry.name.toLowerCase().endsWith('.gif'))) ...[
                  const Text('Preview:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(
                      maxHeight: 400,
                      maxWidth: 300,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(fileEntry.path!),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Failed to load image'),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  const Text('File saved to temporary directory'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      
      LoggingService.instance.log('Layer 3 Test: Successfully completed');
    } catch (e, stackTrace) {
      LoggingService.instance.log('Layer 3 Test: ERROR - $e');
      LoggingService.instance.log('Stack trace: $stackTrace');
      
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      _showErrorDialog('Layer 3 Test failed: $e');
    }
    
    LoggingService.instance.log('=== Layer 3 Test: Finished ===');
  }
  
  Future<void> _downloadRadioWav() async {
    LoggingService.instance.log('=== Download radio.wav: Starting ===');
    
    if (!_isConnected) {
      LoggingService.instance.log('Download radio.wav: Not connected to Bluetooth device');
      _showErrorDialog('Not connected to Bluetooth device');
      return;
    }
    
    LoggingService.instance.log('Download radio.wav: Device is connected');
    
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Request radio.wav file
      final fileEntry = await FileTransferService.instance.requestFile('radio.wav');
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show success dialog with play option
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Download Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File: ${fileEntry.name}'),
              Text('Size: ${fileEntry.size} bytes'),
              const SizedBox(height: 16),
              const Text(
                'File downloaded successfully!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            if (fileEntry.path != null)
              TextButton(
                onPressed: () {
                  _playAudio(fileEntry.path!);
                },
                child: const Text('Play'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      
      LoggingService.instance.log('Download radio.wav: Successfully completed');
    } catch (e, stackTrace) {
      LoggingService.instance.log('Download radio.wav: ERROR - $e');
      LoggingService.instance.log('Stack trace: $stackTrace');
      
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      _showErrorDialog('Failed to download radio.wav: $e');
    }
    
    LoggingService.instance.log('=== Download radio.wav: Finished ===');
  }
}


class _MessagesList extends StatelessWidget {
  final List<Interaction> interactions;
  final bool isTyping;
  final ScrollController scrollController;
  final Function(String) onPlayAudio;
  final String? currentlyPlayingAudio;

  const _MessagesList({
    required this.interactions,
    required this.isTyping,
    required this.scrollController,
    required this.onPlayAudio,
    required this.currentlyPlayingAudio,
  });

  List<ChatMessage> _convertInteractionsToMessages() {
    final List<ChatMessage> messages = [];
    for (final interaction in interactions) {
      // Add user message if user query exists
      if (interaction.userQuery.isNotEmpty) {
        messages.add(ChatMessage(
          text: interaction.userQuery,
          isFromUser: true,
          timestamp: interaction.timestamp,
          audioFilePath: interaction.userAudioFilePath,
        ));
      }
      // Add AI message if AI response exists
      if (interaction.aiResponse.isNotEmpty) {
        messages.add(ChatMessage(
          text: interaction.aiResponse,
          isFromUser: false,
          timestamp: interaction.timestamp,
        ));
      }
    }
    return messages;
  }

  @override
  Widget build(BuildContext context) {
    final messages = _convertInteractionsToMessages();
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

  const _RecordingIndicator({
    required this.currentTranscript,
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
          Expanded(
            child: Text(
              currentTranscript.isEmpty 
                ? 'Recording...' 
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