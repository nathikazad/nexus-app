import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:openai_realtime_dart/openai_realtime_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  static final OpenAIService _instance = OpenAIService._internal();
  factory OpenAIService() => _instance;
  OpenAIService._internal();

  RealtimeClient? _client;
  bool _isConnected = false;
  StreamController<Map<String, dynamic>> _conversationController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get conversationStream => _conversationController.stream;
  bool get isConnected => _isConnected;

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

      // Add list_people tool
      // await _client!.addTool(
      //   const ToolDefinition(
      //     name: 'list_people',
      //     description: 'List all people in your Personal Knowledge Management (PKM) database. Returns their names and descriptions.',
      //     parameters: {
      //       'type': 'object',
      //       'properties': {},
      //       'required': [],
      //     },
      //   ),
      //   (Map<String, dynamic> params) async {
      //     debugPrint('List people tool called with params: $params');
      //     try {
      //       // Call the PKM MCP server
      //       final url = 'http://localhost:8000/mcp';
      //       final requestBody = {
      //         'jsonrpc': '2.0',
      //         'method': 'tools/call',
      //         'params': {
      //           'name': 'list_people',
      //           'arguments': {}
      //         },
      //         'id': DateTime.now().millisecondsSinceEpoch,
      //       };
            
      //       final response = await http.post(
      //         Uri.parse(url),
      //         headers: {
      //           'Content-Type': 'application/json',
      //           'Accept': 'application/json, text/event-stream',
      //         },
      //         body: jsonEncode(requestBody),
      //       );
            
      //       if (response.statusCode == 200) {
      //         final result = jsonDecode(response.body);
      //         debugPrint('MCP List People API result: $result');
              
      //         // Extract the people list from the MCP response
      //         if (result['result'] != null && result['result']['structuredContent'] != null) {
      //           final peopleResult = result['result']['structuredContent']['result'];
      //           return {
      //             'people': peopleResult['people'],
      //             'count': peopleResult['count'],
      //             'message': peopleResult['message'],
      //           };
      //         } else {
      //           return {'error': 'Invalid response format from MCP server'};
      //         }
      //       } else {
      //         debugPrint('MCP List People API error: ${response.statusCode} - ${response.body}');
      //         return {'error': 'HTTP ${response.statusCode}: ${response.body}'};
      //       }
      //     } catch (e) {
      //       debugPrint('MCP List People API error: $e');
      //       return {'error': e.toString()};
      //     }
      //   },
      // );

      // // Add add_people tool
      // await _client!.addTool(
      //   const ToolDefinition(
      //     name: 'add_people',
      //     description: 'Add a new person to your Personal Knowledge Management (PKM) database. Requires a name and optionally a description.',
      //     parameters: {
      //       'type': 'object',
      //       'properties': {
      //         'name': {
      //           'type': 'string',
      //           'description': 'The name of the person to add (required)',
      //         },
      //         'description': {
      //           'type': 'string',
      //           'description': 'A description of the person (optional)',
      //         },
      //       },
      //       'required': ['name'],
      //     },
      //   ),
      //   (Map<String, dynamic> params) async {
      //     debugPrint('Add people tool called with params: $params');
      //     try {
      //       // Call the PKM MCP server
      //       final url = 'http://localhost:8000/mcp';
      //       final requestBody = {
      //         'jsonrpc': '2.0',
      //         'method': 'tools/call',
      //         'params': {
      //           'name': 'add_people',
      //           'arguments': {
      //             'name': params['name'],
      //             'description': params['description'] ?? '',
      //           }
      //         },
      //         'id': DateTime.now().millisecondsSinceEpoch,
      //       };
            
      //       final response = await http.post(
      //         Uri.parse(url),
      //         headers: {
      //           'Content-Type': 'application/json',
      //           'Accept': 'application/json, text/event-stream',
      //         },
      //         body: jsonEncode(requestBody),
      //       );
            
      //       if (response.statusCode == 200) {
      //         final result = jsonDecode(response.body);
      //         debugPrint('MCP Add People API result: $result');
              
      //         // Extract the result from the MCP response
      //         if (result['result'] != null && result['result']['structuredContent'] != null) {
      //           final addResult = result['result']['structuredContent']['result'];
      //           return {
      //             'success': addResult['success'],
      //             'person': addResult['person'],
      //             'message': addResult['message'],
      //             'error': addResult['error'],
      //           };
      //         } else {
      //           return {'error': 'Invalid response format from MCP server'};
      //         }
      //       } else {
      //         debugPrint('MCP Add People API error: ${response.statusCode} - ${response.body}');
      //         return {'error': 'HTTP ${response.statusCode}: ${response.body}'};
      //       }
      //     } catch (e) {
      //       debugPrint('MCP Add People API error: $e');
      //       return {'error': e.toString()};
      //     }
      //   },
      // );

      // Configure session for voice interaction
      await _client!.updateSession(
        instructions: 'You are a helpful voice assistant with access to a Personal Knowledge Management (PKM) database. You have two tools available: 1) list_people - to retrieve all people in the knowledge base with their names and descriptions, and 2) add_people - to add new people with a name (required) and description (optional). When users ask to see people, list people, or show contacts, use list_people. When users want to add someone, save a person, or remember someone, use add_people. Always call the appropriate tool first, then provide a natural response based on the result. Respond naturally and conversationally in English.',
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
          _conversationController.add({
            'speaker': 'AI',
            'audio': delta!.audio,
            'type': 'audio',
          });
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


    _client!.realtime.on(RealtimeEventType.responseDone, (event) {
      try {
        print('Response done event');
        _conversationController.add({
          'type': 'response_done',
        });
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
  Future<void> sendAudio(Uint8List audioData) async {
    if (_client == null || !_isConnected) {
      debugPrint('Client not connected');
      return;
    }

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