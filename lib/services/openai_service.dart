import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:openai_realtime_dart/openai_realtime_dart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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

      await _client!.addTool(
        const ToolDefinition(
          name: 'roll_dice',
          description: 'Roll a dice and get a random number from 0 to 100.',
          parameters: {
            'type': 'object',
            'properties': {},
            'required': [],
          },
        ),
        (Map<String, dynamic> params) async {
          debugPrint('Dice tool called with params: $params');
          try {
            // Call the MCP server
            final url = 'http://localhost:8000/mcp';
            final requestBody = {
              'jsonrpc': '2.0',
              'method': 'tools/call',
              'params': {
                'name': 'roll_dice',
                'arguments': {}
              },
              'id': DateTime.now().millisecondsSinceEpoch,
            };
            
            final response = await http.post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json, text/event-stream',
              },
              body: jsonEncode(requestBody),
            );
            
            if (response.statusCode == 200) {
              final result = jsonDecode(response.body);
              debugPrint('MCP Dice API result: $result');
              
              // Extract the dice result from the MCP response
              if (result['result'] != null && result['result']['structuredContent'] != null) {
                final diceResult = result['result']['structuredContent']['result'];
                return {
                  'result': diceResult['result'],
                  'range': diceResult['range'],
                  'message': diceResult['message'],
                };
              } else {
                return {'error': 'Invalid response format from MCP server'};
              }
            } else {
              debugPrint('MCP Dice API error: ${response.statusCode} - ${response.body}');
              return {'error': 'HTTP ${response.statusCode}: ${response.body}'};
            }
          } catch (e) {
            debugPrint('MCP Dice API error: $e');
            return {'error': e.toString()};
          }
        },
      );

      // Configure session for voice interaction
      await _client!.updateSession(
        instructions: 'You are a helpful voice assistant. You have access to a dice rolling tool called roll_dice. When users ask you to roll a dice, roll some dice, or want a random number, you MUST use the roll_dice tool. The tool will return a random number from 0 to 100. Always call the tool first, then provide a natural response based on the dice result. Respond naturally and conversationally in English.',
        voice: Voice.alloy,
        turnDetection: TurnDetection(
          type: TurnDetectionType.serverVad,
        ),
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

  void debugConversationEvent(FormattedItem? item, Delta? delta) {
    String itemSummary = '';
      if (item != null) {
        itemSummary = 'FormattedItem(item: ${item.formatted?.transcript}';
        // if (item.formatted?.audio != null) {
        //   itemSummary += 'audio: [length: ${item.formatted?.audio.length}], ';
        // } else {
        //   itemSummary += 'audio: null, ';
        // }
        itemSummary += 'text: ${item.formatted?.text}, transcript: ${item.formatted?.transcript}, tool: ${item.formatted?.tool}, output: ${item.formatted?.output})';
      }
      // Create a custom string representation for delta to avoid printing large audio arrays
      String deltaSummary = '';
      if (delta != null) {
        deltaSummary = 'Delta(transcript: ${delta.transcript}, ';
        if (delta.audio != null) {
          deltaSummary += 'audio_length: [length: ${delta.audio!.length}], ';
          deltaSummary += 'audio: ${delta.audio!}], ';
        } else {
          // deltaSummary += 'audio: null, ';
        }
        deltaSummary += 'text: ${delta.text}, arguments: ${delta.arguments})';
      }
      debugPrint('_setupEventHandlers: item: $itemSummary, delta: $deltaSummary');
  }

  void _setupEventHandlers() {
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

    // Handle conversation interruptions
    _client!.on(RealtimeEventType.conversationInterrupted, (event) {
      // Conversation interrupted
    });

    // Handle errors
    _client!.on(RealtimeEventType.error, (event) {
      final errorEvent = event as RealtimeEventError;
      debugPrint('OpenAI API Error: ${errorEvent.error}');
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
      debugPrint('Client not connected');
      return;
    }

    try {
      await _client!.sendUserMessageContent([
        ContentPart.text(text: text),
      ]);
    } catch (e) {
      debugPrint('Error sending text message: $e');
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