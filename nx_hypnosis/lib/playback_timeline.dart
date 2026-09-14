class PlaybackSegment {
  const PlaybackSegment(this.id, this.text, this.start, this.end);
  final String id, text;
  final double start, end;
}

class PlaybackTimeline {
  PlaybackTimeline(this.segments);
  final List<PlaybackSegment> segments;

  static PlaybackTimeline? fromAudio(dynamic audio) {
    if (audio is! Map || audio['link'] is! String) return null;
    final timeline = audio['timeline'];
    if (timeline is! Map ||
        timeline['version'] != 1 ||
        audio['sha256'] is! String ||
        timeline['audio_sha256'] != audio['sha256']) {
      return null;
    }
    final raw = timeline['segments'];
    if (raw is! List || raw.isEmpty) return null;
    final result = <PlaybackSegment>[];
    final ids = <String>{};
    for (final item in raw) {
      if (item is! Map) return null;
      final id = item['id'], text = item['text'];
      final start = item['start_seconds'], end = item['end_seconds'];
      if (id is! String ||
          !ids.add(id) ||
          text is! String ||
          start is! num ||
          end is! num ||
          !start.isFinite ||
          !end.isFinite ||
          start < 0 ||
          end <= start ||
          (result.isNotEmpty && start < result.last.end)) {
        return null;
      }
      result.add(PlaybackSegment(id, text, start.toDouble(), end.toDouble()));
    }
    final duration = audio['duration_seconds'];
    if (duration is num && result.last.end > duration + .1) return null;
    return PlaybackTimeline(List.unmodifiable(result));
  }

  int indexAt(Duration position) {
    final seconds = position.inMicroseconds / 1000000;
    var lo = 0, hi = segments.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (segments[mid].start <= seconds) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }
}
