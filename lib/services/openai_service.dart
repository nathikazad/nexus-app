import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nexus_voice_assistant/services/hardware_service.dart';
import 'package:nexus_voice_assistant/services/agent_tool_service.dart';
import 'package:openai_realtime_dart/openai_realtime_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum queryOrigin {
  App,
  Hardware,
}

class OpenAIService {
  static final OpenAIService _instance = OpenAIService._internal();
  
  /// Singleton instance getter
  static OpenAIService get instance => _instance;
  
  factory OpenAIService() => _instance;
  OpenAIService._internal();

  RealtimeClient? _client;
  bool _isConnected = false;
  StreamController<Map<String, dynamic>> _conversationController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Uint8List> _hardWareAudioController = StreamController<Uint8List>.broadcast();

  Stream<Map<String, dynamic>> get conversationStream => _conversationController.stream;
  Stream<Uint8List> get hardWareAudioOutStream => _hardWareAudioController.stream;
  bool get isConnected => _isConnected;

  queryOrigin _queryOrigin = queryOrigin.App;

  Future<bool> initialize() async {
    try {
      // Load environment variables
      await dotenv.load();
      
      // Get API key from environment variables
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('Error: OPENAI_API_KEY not found in environment variables');
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
      debugPrint('Error initializing OpenAI service: $e');
      return false;
    }
  }

  Future<bool> connect() async {
    if (_client == null) {
      return false;
    }

    try {
      await _client!.connect(model: 'gpt-4o-realtime-preview');
      _isConnected = true;
      return true;
    } catch (e) {
      debugPrint('Error connecting to OpenAI: $e');
      return false;
    }
  }

  void _setupEventHandlers() {
    print('Setting up event handlers');
    if (_client == null) {
      return;
    }

    // Handle conversation updates
    _client!.on(RealtimeEventType.conversationUpdated, (event) {
      final conversationEvent = event as RealtimeEventConversationUpdated;
      final item = conversationEvent.result.item;
      final delta = conversationEvent.result.delta;

      if (item?.item case final ItemMessage message) {
        if (delta?.transcript != null) {
          String speaker = message.role == ItemRole.assistant ? 'AI' : 'You';
          String word = delta!.transcript!;
          
          // Stream the speaker and word
          _conversationController.add({
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
        }
      }
    });

    // // Handle all server events (including response.done for EOF detection)
    // _client!.on(RealtimeEventType.all, (event) {
    //   try {
    //     // Try to access event properties dynamically
    //     final eventMap = event as dynamic;
    //     final eventType = eventMap.type?.toString() ?? '';
        
    //     print('Server event type: $eventType');
        
    //   } catch (e) {
    //     debugPrint('Error handling server event: $e');
    //   }
    // });


    _client!.realtime.on(RealtimeEventType.responseDone, (event) async {
      try {
        print('Response done event');
        _conversationController.add({
          'type': 'response_done',
        });
        if (_queryOrigin == queryOrigin.Hardware) {
          HardwareService.instance.sendEOAudioToEsp32();
        }
      } catch (e) {
        print('Error handling response done event: $e');
      }
    });

  }

  Future<void> disconnect() async {
    if (_client != null && _isConnected) {
      try {
        await _client!.disconnect();
        _isConnected = false;
      } catch (e) {
        debugPrint('Error disconnecting: $e');
      }
    }
  }

  // Send audio data to OpenAI
  Future<void> sendAudio(Uint8List audioData, queryOrigin origin) async {
    if (_client == null || !_isConnected) {
      debugPrint('Client not connected');
      return;
    }

    _queryOrigin = origin;

    try {
      // debugPrint('OpenAIService: Sending audio data (${audioData.length} bytes)');
      await _client!.appendInputAudio(audioData);
    } catch (e) {
      debugPrint('Error sending audio: $e');
    }
  }

  // Send text message
  Future<void> sendTextMessage(String text) async {
    if (_client == null || !_isConnected) {
      print('Client not connected');
      return;
    }

    try {
      print('Sending text message: $text');
      await _client!.sendUserMessageContent([
        // Realtime user messages must be "input_text" (not "text")
        ContentPart.inputText(text: text),
      ]);
    } catch (e) {
      print('Error sending text message: $e');
    }
  }

  // Create response (for manual mode)
  Future<void> createResponse() async {
    if (_client == null || !_isConnected) {
      debugPrint('Client not connected');
      return;
    }

    try {
      await _client!.createResponse();
    } catch (e) {
      debugPrint('Error creating response: $e');
    }
  }


  Future<void> dispose() async {
    await disconnect();
    await _conversationController.close();
  }
}