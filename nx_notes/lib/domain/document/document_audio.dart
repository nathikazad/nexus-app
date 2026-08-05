class DocumentAudioBlockTiming {
  const DocumentAudioBlockTiming({
    required this.blockIndex,
    required this.blockKey,
    required this.start,
    required this.end,
  });

  final int blockIndex;
  final String blockKey;
  final Duration start;
  final Duration end;

  Map<String, Object> toJson() => <String, Object>{
    'block_index': blockIndex,
    'block_key': blockKey,
    'start_ms': start.inMilliseconds,
    'end_ms': end.inMilliseconds,
  };

  static DocumentAudioBlockTiming? tryParse(Object? value) {
    if (value is! Map) return null;
    final blockIndex = _asInt(value['block_index']);
    final blockKey = value['block_key'];
    final startMs = _asInt(value['start_ms']);
    final endMs = _asInt(value['end_ms']);
    if (blockIndex == null ||
        blockKey is! String ||
        blockKey.isEmpty ||
        startMs == null ||
        endMs == null ||
        endMs < startMs) {
      return null;
    }
    return DocumentAudioBlockTiming(
      blockIndex: blockIndex,
      blockKey: blockKey,
      start: Duration(milliseconds: startMs),
      end: Duration(milliseconds: endMs),
    );
  }
}

class DocumentAudioManifest {
  const DocumentAudioManifest({required this.duration, required this.blocks});

  final Duration duration;
  final List<DocumentAudioBlockTiming> blocks;

  Map<String, Object> toJson() => <String, Object>{
    'duration_ms': duration.inMilliseconds,
    'blocks': blocks.map((block) => block.toJson()).toList(growable: false),
  };

  static DocumentAudioManifest? tryParse(Object? value) {
    if (value is! Map) return null;
    final durationMs = _asInt(value['duration_ms']);
    final rawBlocks = value['blocks'];
    if (durationMs == null || rawBlocks is! List) return null;
    final blocks = rawBlocks
        .map(DocumentAudioBlockTiming.tryParse)
        .whereType<DocumentAudioBlockTiming>()
        .toList(growable: false);
    if (blocks.isEmpty) return null;
    return DocumentAudioManifest(
      duration: Duration(milliseconds: durationMs),
      blocks: blocks,
    );
  }

  DocumentAudioBlockTiming? blockAt(Duration position) {
    for (final block in blocks) {
      if (position >= block.start && position < block.end) return block;
    }
    return position >= duration ? blocks.last : null;
  }

  DocumentAudioBlockTiming? blockForKey(String? key) {
    if (key == null) return null;
    for (final block in blocks) {
      if (block.blockKey == key) return block;
    }
    return null;
  }
}

class DocumentAudio {
  const DocumentAudio({
    required this.url,
    required this.sourceHash,
    required this.manifest,
  });

  final String url;
  final String sourceHash;
  final DocumentAudioManifest manifest;
}

int? _asInt(Object? value) {
  return switch (value) {
    final int number => number,
    final num number => number.toInt(),
    final String text => int.tryParse(text),
    _ => null,
  };
}
