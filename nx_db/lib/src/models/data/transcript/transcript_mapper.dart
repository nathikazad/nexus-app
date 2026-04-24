import 'dart:convert';

import '../../domain/transcript/transcript.dart';

/// Parses `getCurrentTranscript` payload (string, `json` wrapper, or map) to [Transcript].
Transcript? parseTranscriptFromGraphqlResponse(dynamic transcriptData) {
  if (transcriptData is String) {
    try {
      transcriptData = json.decode(transcriptData) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  if (transcriptData is Map<String, dynamic> &&
      transcriptData.containsKey('json')) {
    transcriptData = transcriptData['json'];
    if (transcriptData is String) {
      transcriptData = json.decode(transcriptData) as Map<String, dynamic>;
    }
  }

  if (transcriptData == null || transcriptData is! Map<String, dynamic>) {
    return null;
  }

  return Transcript.fromJson(transcriptData);
}
