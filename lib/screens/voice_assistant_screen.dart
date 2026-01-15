import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/audio_service.dart';
import '../services/openai_service.dart';
import '../services/hardware_service/hardware_service.dart';
import '../services/hardware_service/battery_service.dart';
import '../services/file_transfer_service.dart';
import '../widgets/audio_stream_manager.dart';
import '../widgets/message_bubble.dart';
import '../widgets/input_area.dart';
import 'hardware_screen.dart';

class Interaction {
  String userQuery;
  String aiResponse;
  final DateTime timestamp;
  String? userAudioFilePath;
  
  Interaction({
    required this.userQuery,
    required this.aiResponse,
    required this.timestamp,
    this.userAudioFilePath,
  });

  void addToAiResponse(String word) {
    aiResponse += word;
  }

  void addToUserQuery(String word) {
    userQuery += word;
  }

  void setUserAudioFilePath(String filePath) {
    userAudioFilePath = filePath;
  }
}

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  final AudioService _audioService = AudioService();
  final OpenAIService _openAIService = OpenAIService.instance;
  final HardwareService _hardwareService = HardwareService.instance;
  final AudioStreamManager _audioStreamManager = AudioStreamManager();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final List<Interaction> _interactions = [Interaction(userQuery: '', aiResponse: '', timestamp: DateTime.now())];

  
  bool _isRecording = false;
  bool _isConnected = false;
  bool _isTyping = false;
  bool _speakerEnabled = false;
  String _currentTranscript = '';
  String? _currentlyPlayingAudio;
  int? _batteryPercentage;
  bool? _isCharging;
  // int _turnCount = 0;
  
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<Map<String, dynamic>>? _conversationSubscription;
  StreamSubscription<bool>? _bleConnectionSubscription;
  StreamSubscription<BatteryData>? _batterySubscription;

  @override
  void initState() {
    super.initState();
    // Initialize with the last interaction or create a new one
    
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
          if (!isConnected) {
            _batteryPercentage = null;
            _isCharging = null;
          }
        });
      }
    });
    
    // Listen to battery updates (polling handled by Hardware service)
    _batterySubscription = _hardwareService.batteryStream?.listen((batteryData) {
      if (mounted) {
        setState(() {
          _batteryPercentage = batteryData.percentage;
          _isCharging = batteryData.isCharging;
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
      
      // BLE connection state is now handled by _setupBLEConnectionListener()
      bool responseDone = false;
      // Listen to conversation stream
      _conversationSubscription = _openAIService.conversationStream.listen((data) {
        Interaction currentInteraction = _interactions.last;
        
        String type = data['type']!;
        
        if (type == 'transcript') {
          String speaker = data['speaker']!;
          String word = data['word']!;

          // print('speaker: $speaker, word: $word');
          setState(() {
            if (speaker == 'AI') {
              responseDone = false;
              // print('AI: ${currentInteraction.aiResponse + word}');
              // Update the current interaction's AI response
              currentInteraction.addToAiResponse(word);
            } else {
              // Update the current interaction's user query
              currentInteraction.addToUserQuery(word);
              if(responseDone) {
                print('creating new interaction');
                _interactions.add(Interaction(
                  userQuery: '',
                  aiResponse: '',
                  timestamp: DateTime.now(),
                  userAudioFilePath: currentInteraction.userAudioFilePath,
                ));
              }
            }
          });
          _scrollToBottom();
        } else if (type == 'audio' && data['speaker'] == 'AI') {
          // Handle streamed audio from AI - only play if speaker is enabled
          if (_speakerEnabled) {
            Uint8List audioData = data['audio']!;
            _audioStreamManager.playStreamedAudio(audioData);
          }
        } else if (type == 'response_done') {

          responseDone = true;
          // Create new interaction for next turn
          if(!currentInteraction.userQuery.isEmpty) {
            print('creating new interaction');
            _interactions.add(Interaction(
              userQuery: '',
              aiResponse: '',
              timestamp: DateTime.now(),
              userAudioFilePath: currentInteraction.userAudioFilePath,
            ));
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
          debugPrint('Error creating response after recording stop: $e');
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
    _bleConnectionSubscription?.cancel();
    _batterySubscription?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    _audioPlayer.dispose();
    _audioService.dispose();
    _openAIService.dispose();
    _hardwareService.dispose();
    _audioStreamManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _VoiceAssistantAppBar(
        isConnected: _isConnected,
        isPlayingStreamedAudio: _audioStreamManager.isPlayingStreamedAudio,
        batteryPercentage: _batteryPercentage,
        isCharging: _isCharging,
        onBluetoothIconTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HardwareScreen()),
          );
        },
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
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _testLayer2,
            tooltip: 'Test Layer 2 (List Files)',
            child: const Icon(Icons.folder),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            onPressed: _testLayer3,
            tooltip: 'Test Layer 3 (Receive File)',
            child: const Icon(Icons.download),
          ),
        ],
      ),
    );
  }
  
  Future<void> _testLayer2() async {
    debugPrint('=== Layer 2 Test: Starting file list request ===');
    
    if (!_isConnected) {
      debugPrint('Layer 2 Test: Not connected to Bluetooth device');
      _showErrorDialog('Not connected to Bluetooth device');
      return;
    }
    
    debugPrint('Layer 2 Test: Device is connected');
    
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
      
      debugPrint('Layer 2 Test: Successfully completed');
    } catch (e, stackTrace) {
      debugPrint('Layer 2 Test: ERROR - $e');
      debugPrint('Layer 2 Test: Stack trace: $stackTrace');
      
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _showErrorDialog('Failed to list files: $e');
    }
    
    debugPrint('=== Layer 2 Test: Finished ===');
  }
  
  Future<void> _testLayer3() async {
    debugPrint('=== Layer 3 Test: Starting file receive (image1.jpg) ===');
    
    if (!_isConnected) {
      debugPrint('Layer 3 Test: Not connected to Bluetooth device');
      _showErrorDialog('Not connected to Bluetooth device');
      return;
    }
    
    debugPrint('Layer 3 Test: Device is connected');
    
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
      
      debugPrint('Layer 3 Test: Successfully completed');
    } catch (e, stackTrace) {
      debugPrint('Layer 3 Test: ERROR - $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      _showErrorDialog('Layer 3 Test failed: $e');
    }
    
    debugPrint('=== Layer 3 Test: Finished ===');
  }
}



class _VoiceAssistantAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isConnected;
  final bool isPlayingStreamedAudio;
  final int? batteryPercentage;
  final bool? isCharging;
  final VoidCallback? onBluetoothIconTap;

  const _VoiceAssistantAppBar({
    required this.isConnected,
    required this.isPlayingStreamedAudio,
    this.batteryPercentage,
    this.isCharging,
    this.onBluetoothIconTap,
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
              // Battery indicator (only show when connected)
              if (isConnected && batteryPercentage != null) ...[
                if (isCharging == true) ...[
                  const Icon(
                    Icons.battery_charging_full,
                    color: Colors.green,
                    size: 18,
                  ),
                ] else ...[
                  Icon(
                    Icons.battery_std,
                    color: _getBatteryColor(batteryPercentage!),
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$batteryPercentage%',
                    style: TextStyle(
                      fontSize: 12,
                      color: _getBatteryColor(batteryPercentage!),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: onBluetoothIconTap,
                child: Icon(
                  isConnected ? Icons.bluetooth : Icons.bluetooth_disabled,
                  color: isConnected ? Colors.blue : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Color _getBatteryColor(int percentage) {
    if (percentage >= 50) {
      return Colors.green;
    } else if (percentage >= 20) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
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