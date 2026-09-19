import 'package:flutter/services.dart';
import 'drawing.dart';

/// Host-facing editor port. Persistence/account policy belongs to the host.
abstract interface class CanvasClient {
  Future<bool> available();
  Future<CanvasSavedDrawing?> recover();
  Future<CanvasSavedDrawing?> peek(String? afterToken);
  Future<CanvasSavedDrawing?> open(CanvasOpenRequest request);
  Future<bool> acknowledge(String token);
  Future<void> diagnostic(Map<String, Object> event);
}

class CanvasOpenRequest {
  const CanvasOpenRequest({
    required this.sessionId,
    required this.title,
    required this.drawing,
    this.backLabel = '‹ Drawings',
  });
  final String sessionId, title, backLabel;
  final Drawing drawing;
  Map<String, Object?> toJson() => {
    ...drawing.toJson(),
    'documentId': sessionId,
    'title': title,
    'backLabel': backLabel,
  };
}

class CanvasSavedDrawing {
  const CanvasSavedDrawing({
    required this.sessionId,
    required this.token,
    required this.drawing,
  });
  final String sessionId, token;
  final Drawing drawing;
  factory CanvasSavedDrawing.fromJson(Map<String, dynamic> json) {
    if (json['documentId'] is! String ||
        json['saveToken'] is! String ||
        json['drawing'] is! Map) {
      throw const FormatException('Invalid canvas recovery envelope');
    }
    return CanvasSavedDrawing(
      sessionId: json['documentId'] as String,
      token: json['saveToken'] as String,
      drawing: Drawing.fromJson(
        Map<String, dynamic>.from(json['drawing'] as Map),
      ),
    );
  }
}

class MethodChannelCanvasClient implements CanvasClient {
  const MethodChannelCanvasClient({
    this.channel = const MethodChannel('nx_canvas/editor'),
  });
  final MethodChannel channel;
  @override
  Future<bool> available() async =>
      await channel.invokeMethod<bool>('available') == true;
  Future<CanvasSavedDrawing?> _read(String method, [Object? args]) async {
    final result = await channel.invokeMapMethod<String, dynamic>(method, args);
    return result == null ? null : CanvasSavedDrawing.fromJson(result);
  }

  @override
  Future<CanvasSavedDrawing?> recover() => _read('recoverDocument');
  @override
  Future<CanvasSavedDrawing?> peek(String? afterToken) =>
      _read('peekDocument', afterToken);
  @override
  Future<CanvasSavedDrawing?> open(CanvasOpenRequest request) =>
      _read('openDocument', request.toJson());
  @override
  Future<bool> acknowledge(String token) async =>
      await channel.invokeMethod<bool>('ackDocument', token) == true;
  @override
  Future<void> diagnostic(Map<String, Object> event) =>
      channel.invokeMethod<void>('diagnostic', event);
}
