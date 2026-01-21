import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../logging_service.dart';

/// Calls an MCP tool and returns the result
/// 
/// [toolName] - The name of the tool to call on the MCP server
/// [arguments] - Optional arguments to pass to the tool
/// [mcpUrl] - The URL of the MCP server (defaults to http://localhost:8000/mcp)
/// 
/// Returns a Map with the tool result or an error
Future<Map<String, dynamic>> callMCPTool(
  String toolName, {
  Map<String, dynamic>? arguments,
  String mcpUrl = 'https://b79fcf799613.ngrok-free.app/mcp',
}) async {
  LoggingService.instance.log('MCP tool called: $toolName with params: $arguments');
  
  try {
    final requestBody = {
      'jsonrpc': '2.0',
      'method': 'tools/call',
      'params': {
        'name': toolName,
        'arguments': arguments ?? {},
      },
      'id': DateTime.now().millisecondsSinceEpoch,
    };
    
    final response = await http.post(
      Uri.parse(mcpUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/event-stream',
      },
      body: jsonEncode(requestBody),
    );
    
    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      LoggingService.instance.log('MCP $toolName API result: $result');
      
      // Check for MCP errors
      if (result['error'] != null) {
        return {'error': 'MCP error: ${result['error']}'};
      }
      
      // Extract the result from the MCP response
      // FastMCP with json_response=True returns the tool result directly in result['result']
      if (result['result'] != null) {
        final toolResult = result['result'];
        
        // Handle string responses (e.g., ask_user_data_agent returns a string)
        if (toolResult is String) {
          return {'answer': toolResult};
        }
        
        // Check if it's structured content (for tools like list_people)
        if (toolResult is Map) {
          if (toolResult['structuredContent'] != null) {
            final structuredResult = toolResult['structuredContent']['result'];
            // Handle structured responses (e.g., list_people)
            if (structuredResult is Map && structuredResult.containsKey('people')) {
              return {
                'people': structuredResult['people'],
                'count': structuredResult['count'],
                'message': structuredResult['message'],
              };
            }
            // Handle other structured responses
            return structuredResult is Map 
                ? structuredResult as Map<String, dynamic>
                : {'answer': structuredResult.toString()};
          }
          // Direct map result
          return toolResult as Map<String, dynamic>;
        }
        
        // Fallback: convert to string
        return {'answer': toolResult.toString()};
      }
      return {'error': 'Invalid response format from MCP server: no result field'};
    } else {
      LoggingService.instance.log('MCP $toolName API error: ${response.statusCode} - ${response.body}');
      return {'error': 'HTTP ${response.statusCode}: ${response.body}'};
    }
  } catch (e) {
    LoggingService.instance.log('MCP $toolName API error: $e');
    return {'error': e.toString()};
  }
}

