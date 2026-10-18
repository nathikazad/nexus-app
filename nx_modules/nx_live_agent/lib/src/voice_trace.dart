import 'dart:convert';

/// Observation only: timestamps are client arrival times, never speaker-frame
/// timestamps. A response may span two cards; origin and current visit differ.
final class VoiceTrace {
  VoiceTrace({required this.write, String? sessionId})
    : sessionId =
          sessionId ?? DateTime.now().toUtc().microsecondsSinceEpoch.toString();
  final void Function(String) write;
  final String sessionId;
  final Stopwatch _clock = Stopwatch()..start();
  int _sequence = 0;
  int _visit = 0;
  Object? _card;
  int speechStops = 0, responsesDone = 0, playbackStops = 0;
  final Map<String, int> _origins = {};
  final Set<String> _counted = {};
  int _cardSpeechBase = 0, _cardResponseBase = 0, _cardPlaybackBase = 0;

  void card(Object? id, int index) {
    if (_visit > 0) log('card_visit_end');
    _visit++;
    _card = id;
    _cardSpeechBase = speechStops;
    _cardResponseBase = responsesDone;
    _cardPlaybackBase = playbackStops;
    log('card_visit_start', {'index': index});
  }

  void log(String event, [Map<String, Object?> data = const {}]) {
    // Logging must never affect the session, even if an output sink fails.
    try {
      final sequence = _sequence++;
      final record = jsonEncode({
        'session_id': sessionId,
        'seq': sequence,
        'utc': DateTime.now().toUtc().toIso8601String(),
        'elapsed_us': _clock.elapsedMicroseconds,
        'clock': 'client_observation',
        'card_id': _card,
        'card_visit': _visit,
        'event': event,
        'speech_stops': speechStops,
        'responses_done': responsesDone,
        'playback_stops': playbackStops,
        'visit_speech_stops': speechStops - _cardSpeechBase,
        'visit_responses_done': responsesDone - _cardResponseBase,
        'visit_playback_stops': playbackStops - _cardPlaybackBase,
        'data': data,
      });
      final parts = (record.length / 650).ceil();
      for (var part = 0; part < parts; part++) {
        final start = part * 650;
        final end = start + 650 < record.length ? start + 650 : record.length;
        write(
          'NxVoiceTrace ${jsonEncode({'session_id': sessionId, 'seq': sequence, 'part': part, 'parts': parts, 'fragment': record.substring(start, end)})}',
        );
      }
    } catch (_) {}
  }

  void wire(String direction, Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    final response = event['response'];
    final item = event['item'];
    final responseId =
        event['response_id'] ?? (response is Map ? response['id'] : null);
    final itemId = event['item_id'] ?? (item is Map ? item['id'] : null);
    final identity = responseId ?? itemId;
    final key = identity == null ? null : '$identity';
    if (key != null) _origins.putIfAbsent(key, () => _visit);
    final counterKey = '$type:$identity:${event['event_id'] ?? ''}';
    // Deduplicate terminal notifications by semantic identity when available.
    final unique = _counted.add(
      identity == null ? counterKey : '$type:$identity',
    );
    if (direction == 'receive' && unique) {
      if (type == 'input_audio_buffer.speech_stopped') speechStops++;
      if (type == 'response.done') responsesDone++;
      if (type == 'output_audio_buffer.stopped') playbackStops++;
    }
    final audioDelta =
        type == 'response.output_audio.delta' || type == 'response.audio.delta';
    log('wire_$direction', {
      'type': type,
      if (key != null) 'origin_card_visit': _origins[key],
      for (final field in [
        'event_id',
        'response_id',
        'item_id',
        'call_id',
        'name',
        'audio_start_ms',
        'audio_end_ms',
        'output_index',
        'content_index',
        'transcript',
        'text',
        'arguments',
      ])
        if (event.containsKey(field)) field: event[field],
      if (event.containsKey('delta') && !audioDelta) 'delta': event['delta'],
      if (audioDelta) 'audio_base64_chars': (event['delta'] as String?)?.length,
      if (response is Map)
        'response': {
          'id': response['id'],
          'status': response['status'],
          'output': _safeItems(response['output']),
        },
      if (item is Map) 'item': _safeItem(item),
      if (event['error'] is Map) 'error_code': (event['error'] as Map)['code'],
    });
  }

  Object? _safeItems(Object? items) =>
      items is List ? items.whereType<Map>().map(_safeItem).toList() : null;
  Map<String, Object?> _safeItem(Map item) => {
    for (final key in [
      'id',
      'type',
      'role',
      'call_id',
      'name',
      'arguments',
      'output',
    ])
      if (item.containsKey(key)) key: item[key],
    if (item['content'] is List)
      'content': [
        for (final part in (item['content'] as List).whereType<Map>())
          {
            for (final key in ['type', 'text', 'transcript'])
              if (part.containsKey(key)) key: part[key],
          },
      ],
  };
}
