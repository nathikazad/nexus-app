import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/services/hardware_service/hardware_service.dart';
import 'package:nexus_voice_assistant/services/ai_service/agent_tool_service.dart';
import 'package:nexus_voice_assistant/auth.dart';
import 'package:openai_realtime_dart/openai_realtime_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../logging_service.dart';

enum queryOrigin {
  App,
  Hardware,
}

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

/// Provider that manages OpenAI service lifecycle based on authentication status.
/// Connects when authenticated, disconnects when unauthenticated.
final openAIServiceProvider = Provider<OpenAIService>((ref) {
  final appStatus = ref.watch(appStatusProvider);
  final service = OpenAIService.instance;
  
  LoggingService.instance.log('[OpenAI Provider] appStatus changed to: $appStatus');
  
  if (appStatus == AppStatus.authenticated) {
    // Connect when authenticated
    LoggingService.instance.log('[OpenAI Provider] User authenticated, initializing and connecting...');
    _initAndConnect(service);
  } else if (appStatus == AppStatus.unauthenticated) {
    // Disconnect and clear interactions when unauthenticated
    LoggingService.instance.log('[OpenAI Provider] User unauthenticated, disconnecting and clearing interactions...');
    service.disconnect();
    service.clearInteractions();
  }
  // When initializing, do nothing - wait for auth to complete
  
  ref.onDispose(() {
    LoggingService.instance.log('[OpenAI Provider] Provider disposed, disconnecting...');
    service.disconnect();
  });
  
  return service;
});

Future<void> _initAndConnect(OpenAIService service) async {
  if (!service.isConnected && !service.isReconnecting) {
    final initSuccess = await service.initialize();
    if (initSuccess) {
      await service.connect();
    }
  }
}

class OpenAIService {
  static final OpenAIService _instance = OpenAIService._internal();
  
  /// Singleton instance getter
  static OpenAIService get instance => _instance;
  
  factory OpenAIService() => _instance;
  OpenAIService._internal();

  RealtimeClient? _client;
  bool _isConnected = false;
  bool _isReconnecting = false;
  bool _shouldAutoReconnect = true; // Set to false during intentional disconnect
  StreamController<Map<String, dynamic>> _conversationController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Uint8List> _hardWareAudioController = StreamController<Uint8List>.broadcast();
  
  // Interaction management
  final List<Interaction> _interactions = [Interaction(userQuery: '', aiResponse: '', timestamp: DateTime.now())];
  final StreamController<List<Interaction>> _interactionsController = StreamController<List<Interaction>>.broadcast();
  bool _responseDone = false;

  Stream<Map<String, dynamic>> get conversationStream => _conversationController.stream;
  Stream<Uint8List> get hardWareAudioOutStream => _hardWareAudioController.stream;
  bool get isConnected => _isConnected;
  bool get isReconnecting => _isReconnecting;
  
  // Interaction getters
  List<Interaction> get interactions => List.unmodifiable(_interactions);
  Stream<List<Interaction>> get interactionsStream => _interactionsController.stream;

  queryOrigin _queryOrigin = queryOrigin.App;

  Future<bool> initialize() async {
    try {
      // Load environment variables
      await dotenv.load();
      
      // Get API key from environment variables
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        LoggingService.instance.log('Error: OPENAI_API_KEY not found in environment variables');
        return false;
      }
      
      _client = RealtimeClient(
        apiKey: apiKey,
        // dangerouslyAllowAPIKeyInBrowser: kIsWeb,
      );

      // Add ask_user_data_expert_agent tool
      await _client!.addTool(
        const ToolDefinition(
          name: 'ask_user_data_expert_agent',
          description: 'Ask the user data expert agent any question about the user.',
          parameters: {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'The natural language question to ask the agent about the user',
              },
            },
            'required': ['query'],
          },
        ),
        (Map<String, dynamic> params) async {
          // Extract query from params (required)
          final query = params['query'] as String?;
          if (query == null || query.isEmpty) {
            return {'error': 'Query parameter is required'};
          }
          
          // Hardcode user_id to 1
          const userId = '1';
          
          return await callMCPTool(
            'ask_user_data_agent',
            arguments: {
              'query': query,
              'user_id': userId,
            },
          );
        },
      );

      // Configure session for voice interaction
      await _client!.updateSession(
        instructions: 'You are a helpful voice assistant with access to a Personal Knowledge Management (PKM) database. You have access to the ask_user_data_expert_agent tool which can answer questions about the user\'s data. When users ask questions about their data, use the ask_user_data_expert_agent tool with their question as the query parameter. Always call the tool first, then provide a natural response based on the result. Respond naturally and conversationally in English.',
        voice: Voice.alloy,
        // Disable automatic turn detection so we control when the model responds
        turnDetection: null,
        inputAudioTranscription: const InputAudioTranscriptionConfig(
          model: 'whisper-1',
          language: 'en',
        ),
        toolChoice: SessionConfigToolChoice.mode(
          SessionConfigToolChoiceMode.auto,
        ),
      );

      // Set up event handlers
      _setupEventHandlers();

      return true;
    } catch (e) {
      LoggingService.instance.log('Error initializing OpenAI service: $e');
      return false;
    }
  }

  Future<bool> connect() async {
    if (_client == null) {
      LoggingService.instance.log('[OpenAI] Cannot connect: client is null');
      return false;
    }

    try {
      LoggingService.instance.log('[OpenAI] Connecting to OpenAI Realtime...');
      await _client!.connect(model: 'gpt-4o-realtime-preview');
      _isConnected = true;
      _shouldAutoReconnect = true; // Enable auto-reconnect after successful connection
      LoggingService.instance.log('[OpenAI] ✓ Connected to OpenAI Realtime');
      return true;
    } catch (e) {
      LoggingService.instance.log('[OpenAI] ✗ Error connecting to OpenAI: $e');
      return false;
    }
  }

  void _setupEventHandlers() {
    LoggingService.instance.log('[OpenAI] Setting up event handlers');
    if (_client == null) {
      return;
    }

    // Monitor connection close/error events on the underlying realtime connection
    _client!.realtime.on(RealtimeEventType.close, (event) {
      LoggingService.instance.log('[OpenAI] ⚠️ WebSocket CLOSED - _isConnected was: $_isConnected, shouldAutoReconnect: $_shouldAutoReconnect');
      _isConnected = false;
      
      // Auto-reconnect if not intentionally disconnected
      if (_shouldAutoReconnect) {
        _attemptReconnect();
      }
    });

    _client!.realtime.on(RealtimeEventType.error, (event) {
      LoggingService.instance.log('[OpenAI] ⚠️ WebSocket ERROR: $event');
    });

    // Log when session is created (connection is fully ready)
    _client!.on(RealtimeEventType.sessionCreated, (event) {
      LoggingService.instance.log('[OpenAI] ✓ Session created - connection fully ready');
    });

    _client!.on(RealtimeEventType.sessionUpdated, (event) {
      LoggingService.instance.log('[OpenAI] Session updated');
    });

    // Handle conversation updates
    _client!.on(RealtimeEventType.conversationUpdated, (event) {
      LoggingService.instance.log('[OpenAI] Conversation updated event received');
      
      final conversationEvent = event as RealtimeEventConversationUpdated;
      final item = conversationEvent.result.item;
      final delta = conversationEvent.result.delta;

      if (item?.item case final ItemMessage message) {
        if (delta?.transcript != null) {
          String speaker = message.role == ItemRole.assistant ? 'AI' : 'You';
          String word = delta!.transcript!;
          
          // Stream the speaker and word (for backward compatibility)
          _conversationController.add({
            'speaker': speaker,
            'word': word,
            'type': 'transcript',
          });
          
          // Update interactions internally
          _handleConversationEvent({
            'speaker': speaker,
            'word': word,
            'type': 'transcript',
          });
        }
        
        // Handle audio data from assistant
        if (delta?.audio != null && message.role == ItemRole.assistant) {
          // Stream the audio data
          if (_queryOrigin == queryOrigin.Hardware) {
            _hardWareAudioController.add(delta!.audio!);
          } else {
            _conversationController.add({
              'speaker': 'AI',
              'audio': delta!.audio,
              'type': 'audio',
            });
          }
        } else if (delta?.audio != null) {
          LoggingService.instance.log('[OpenAI] Audio delta received but role is not assistant: ${message.role}');
        }
      } else {
        LoggingService.instance.log('[OpenAI] Conversation updated but item is not ItemMessage');
      }
    });

    // Handle all server events (including response.done for EOF detection)
    // _client!.on(RealtimeEventType.all, (event) {
    //   try {
    //     // Try to access event properties dynamically
    //     final eventMap = event as dynamic;
    //     final eventType = eventMap.type?.toString() ?? 'unknown';
    //     LoggingService.instance.log('[OpenAI] 📨 Received event: $eventType');
        
    //     // Log full event for debugging (be careful with sensitive data)
    //     if (eventType.contains('error') || eventType.contains('Error')) {
    //       LoggingService.instance.log('[OpenAI] ⚠️ Error event details: $event');
    //     }
    //   } catch (e) {
    //     LoggingService.instance.log('[OpenAI] Error handling all event: $e');
    //   }
    // });


    _client!.realtime.on(RealtimeEventType.responseDone, (event) async {
      try {
        LoggingService.instance.log('[OpenAI] Response done event');
        _conversationController.add({
          'type': 'response_done',
        });
        
        // Update interactions internally
        _handleConversationEvent({'type': 'response_done'});
        
        if (_queryOrigin == queryOrigin.Hardware) {
          HardwareService.instance.sendEOAudioToEsp32();
        }
      } catch (e) {
        LoggingService.instance.log('[OpenAI] Error handling response done event: $e');
      }
    });

    // Log input audio buffer events
    _client!.on(RealtimeEventType.inputAudioBufferCommitted, (event) {
      LoggingService.instance.log('[OpenAI] Input audio buffer committed');
    });

    _client!.on(RealtimeEventType.inputAudioBufferCleared, (event) {
      LoggingService.instance.log('[OpenAI] Input audio buffer cleared');
    });

    // Log response events
    _client!.on(RealtimeEventType.responseCreated, (event) {
      LoggingService.instance.log('[OpenAI] Response created - AI is generating');
    });

    // Add missing event handlers for debugging
    _client!.on(RealtimeEventType.responseAudioDelta, (event) {
      LoggingService.instance.log('[OpenAI] Response audio delta received');
    });

    // Add error event handler on the client (not just realtime)
    _client!.on(RealtimeEventType.error, (event) {
      LoggingService.instance.log('[OpenAI] ⚠️ Client ERROR event: $event');
    });

  }

  /// Manually trigger reconnection (can be called from UI)
  Future<bool> reconnect() async {
    LoggingService.instance.log('[OpenAI] Manual reconnect requested');
    _shouldAutoReconnect = true;
    
    if (_isConnected) {
      LoggingService.instance.log('[OpenAI] Already connected, skipping reconnect');
      return true;
    }
    
    if (_isReconnecting) {
      LoggingService.instance.log('[OpenAI] Already reconnecting, please wait...');
      return false;
    }
    
    await _attemptReconnect();
    return _isConnected;
  }

  /// Attempt to reconnect to OpenAI Realtime API
  Future<void> _attemptReconnect() async {
    if (_isReconnecting) {
      LoggingService.instance.log('[OpenAI] Already attempting to reconnect, skipping...');
      return;
    }
    
    _isReconnecting = true;
    
    // Wait a bit before reconnecting to avoid rapid reconnection attempts
    LoggingService.instance.log('[OpenAI] 🔄 Will attempt to reconnect in 2 seconds...');
    await Future.delayed(const Duration(seconds: 2));
    
    if (!_shouldAutoReconnect) {
      LoggingService.instance.log('[OpenAI] Auto-reconnect cancelled');
      _isReconnecting = false;
      return;
    }
    
    // Need to reinitialize the client since the old one is disconnected
    LoggingService.instance.log('[OpenAI] 🔄 Reinitializing and reconnecting...');
    
    try {
      // Reinitialize the client
      final initSuccess = await initialize();
      if (!initSuccess) {
        LoggingService.instance.log('[OpenAI] ✗ Failed to reinitialize during reconnect');
        _isReconnecting = false;
        return;
      }
      
      // Connect
      final connectSuccess = await connect();
      if (connectSuccess) {
        LoggingService.instance.log('[OpenAI] ✓ Reconnected successfully!');
      } else {
        LoggingService.instance.log('[OpenAI] ✗ Failed to reconnect');
      }
    } catch (e) {
      LoggingService.instance.log('[OpenAI] ✗ Error during reconnect: $e');
    } finally {
      _isReconnecting = false;
    }
  }

  Future<void> disconnect() async {
    LoggingService.instance.log('[OpenAI] Disconnect called - _isConnected: $_isConnected');
    _shouldAutoReconnect = false; // Prevent auto-reconnect during intentional disconnect
    if (_client != null && _isConnected) {
      try {
        await _client!.disconnect();
        _isConnected = false;
        LoggingService.instance.log('[OpenAI] ✓ Disconnected from OpenAI');
      } catch (e) {
        LoggingService.instance.log('[OpenAI] Error disconnecting: $e');
      }
    }
  }

  // Send audio data to OpenAI
  Future<void> sendAudio(Uint8List audioData, queryOrigin origin) async {
    if (_client == null) {
      LoggingService.instance.log('[OpenAI] ✗ sendAudio failed: client is null');
      return;
    }
    if (!_isConnected) {
      LoggingService.instance.log('[OpenAI] ✗ sendAudio failed: not connected (flag is false)');
      return;
    }

    _queryOrigin = origin;

    try {
      LoggingService.instance.log('[OpenAI] Sending audio chunk: ${audioData.length} bytes');
      await _client!.appendInputAudio(audioData);
      LoggingService.instance.log('[OpenAI] ✓ Audio chunk sent successfully');
    } catch (e, stackTrace) {
      LoggingService.instance.log('[OpenAI] ✗ Error sending audio: $e');
      LoggingService.instance.log('[OpenAI] Stack trace: $stackTrace');
      // If we get an error, the connection is likely dead
      _isConnected = false;
    }
  }

  // Send text message
  Future<void> sendTextMessage(String text) async {
    if (_client == null) {
      LoggingService.instance.log('[OpenAI] ✗ sendTextMessage failed: client is null');
      return;
    }
    if (!_isConnected) {
      LoggingService.instance.log('[OpenAI] ✗ sendTextMessage failed: not connected (flag is false)');
      return;
    }

    try {
      LoggingService.instance.log('[OpenAI] Sending text message: $text');
      await _client!.sendUserMessageContent([
        // Realtime user messages must be "input_text" (not "text")
        ContentPart.inputText(text: text),
      ]);
      LoggingService.instance.log('[OpenAI] ✓ Text message sent');
    } catch (e) {
      LoggingService.instance.log('[OpenAI] ✗ Error sending text message: $e');
      _isConnected = false;
    }
  }

  // Create response (for manual mode)
  Future<void> createResponse() async {
    if (_client == null) {
      LoggingService.instance.log('[OpenAI] ✗ createResponse failed: client is null');
      return;
    }
    if (!_isConnected) {
      LoggingService.instance.log('[OpenAI] ✗ createResponse failed: not connected (flag is false)');
      return;
    }

    try {
      LoggingService.instance.log('[OpenAI] Creating response... (queryOrigin: $_queryOrigin)');
      LoggingService.instance.log('[OpenAI] Connection state before createResponse: isConnected=$_isConnected');
      
      await _client!.createResponse();
      
      LoggingService.instance.log('[OpenAI] ✓ createResponse sent successfully');
      
      // Log after a delay to see if any events come back
      Future.delayed(const Duration(seconds: 5), () {
        LoggingService.instance.log('[OpenAI] 5 seconds after createResponse - checking for events...');
      });
    } catch (e, stackTrace) {
      LoggingService.instance.log('[OpenAI] ✗ Error creating response: $e');
      LoggingService.instance.log('[OpenAI] Stack trace: $stackTrace');
      // If we get an error, the connection is likely dead
      _isConnected = false;
    }
  }


  /// Handle conversation events and update interactions
  void _handleConversationEvent(Map<String, dynamic> data) {
    Interaction currentInteraction = _interactions.last;
    String type = data['type']!;

    if (type == 'transcript') {
      String speaker = data['speaker']!;
      String word = data['word']!;

      if (speaker == 'AI') {
        _responseDone = false;
        currentInteraction.addToAiResponse(word);
      } else {
        currentInteraction.addToUserQuery(word);
        if (_responseDone) {
          _interactions.add(Interaction(
            userQuery: '',
            aiResponse: '',
            timestamp: DateTime.now(),
            userAudioFilePath: currentInteraction.userAudioFilePath,
          ));
        }
      }
      _interactionsController.add(_interactions);
    } else if (type == 'response_done') {
      _responseDone = true;
      if (currentInteraction.userQuery.isNotEmpty) {
        _interactions.add(Interaction(
          userQuery: '',
          aiResponse: '',
          timestamp: DateTime.now(),
          userAudioFilePath: currentInteraction.userAudioFilePath,
        ));
      }
      _interactionsController.add(_interactions);
    }
  }

  /// Clear all interactions and start fresh
  void clearInteractions() {
    _interactions.clear();
    _interactions.add(Interaction(userQuery: '', aiResponse: '', timestamp: DateTime.now()));
    _responseDone = false;
    _interactionsController.add(_interactions);
  }

  Future<void> dispose() async {
    await disconnect();
    await _conversationController.close();
    await _interactionsController.close();
  }
}