import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class CanvasTextProposal {
  const CanvasTextProposal({required this.blocks, required this.warnings});
  final List<Map<String, dynamic>> blocks;
  final List<String> warnings;
}

typedef ConvertCanvas =
    Future<CanvasTextProposal> Function(
      String canvasId,
      Map<String, dynamic> drawing,
    );

/// Bound to one authenticated user/domain client; disposal invalidates late results.
class CanvasConversionService {
  CanvasConversionService({
    required String baseUrl,
    required http.Client client,
  }) : _base = Uri.parse(baseUrl),
       _client = client;
  final Uri _base;
  final http.Client _client;
  bool _active = true;
  void dispose() => _active = false;
  void ensureActive() {
    if (!_active) throw StateError('Account changed. Please try again.');
  }

  Future<CanvasTextProposal> convert({
    required int documentId,
    required String canvasId,
    required Map<String, dynamic> drawing,
  }) async {
    ensureActive();
    final random = Random.secure();
    final requestId = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final response = await _client
        .post(
          _base.resolve('/nx_docs/canvas/convert'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'document_id': documentId,
            'canvas_id': canvasId,
            'request_id': requestId,
            'expected_drawing': drawing,
          }),
        )
        .timeout(const Duration(seconds: 250));
    ensureActive();
    final body = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw StateError(
        body is Map
            ? body['error']?.toString() ?? 'Conversion failed.'
            : 'Conversion failed.',
      );
    }
    if (body is! Map ||
        body['document_id'] != documentId ||
        body['canvas_id'] != canvasId ||
        body['request_id'] != requestId) {
      throw StateError(
        'The agent returned a different canvas. Nothing was inserted.',
      );
    }
    final rawBlocks = body['blocks'];
    final warnings = body['warnings'];
    if (rawBlocks is! List ||
        rawBlocks.isEmpty ||
        rawBlocks.length > 200 ||
        warnings is! List ||
        warnings.any((w) => w is! String)) {
      throw StateError('Invalid conversion response.');
    }
    final blocks = <Map<String, dynamic>>[];
    for (final block in rawBlocks) {
      if (block is! Map ||
          block.length != 2 ||
          !block.containsKey('data') ||
          !{
            'paragraph',
            'heading',
            'bulleted_list',
            'numbered_list',
          }.contains(block['type'])) {
        throw StateError('Invalid conversion block.');
      }
      final data = block['data'];
      final heading = block['type'] == 'heading';
      if (data is! Map ||
          data.length != (heading ? 2 : 1) ||
          (heading && !{1, 2, 3}.contains(data['level']))) {
        throw StateError('Invalid conversion block data.');
      }
      final delta = data['delta'];
      if (delta is! List ||
          delta.length != 1 ||
          delta[0] is! Map ||
          (delta[0] as Map).length != 1 ||
          delta[0]['insert'] is! String ||
          (delta[0]['insert'] as String).trim().isEmpty ||
          (delta[0]['insert'] as String).length > 20000) {
        throw StateError('Invalid conversion text.');
      }
      blocks.add(Map<String, dynamic>.from(block));
    }
    return CanvasTextProposal(
      blocks: blocks,
      warnings: warnings.cast<String>(),
    );
  }
}
