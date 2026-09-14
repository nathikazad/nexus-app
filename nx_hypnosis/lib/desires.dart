import 'playback_timeline.dart';
import 'package:flutter/foundation.dart';

class Desire {
  Desire({required this.id, required this.title, required this.belief});
  final String id;
  String title;
  String belief;
}

class Tape {
  Tape({
    required this.id,
    required this.desireId,
    required this.title,
    required this.story,
    this.prompt = '',
    this.audioAsset,
    this.audioRevision,
    this.timeline,
  });
  final String id;
  String desireId;
  String title;
  String story;
  String prompt;
  String? audioAsset;
  String? audioRevision;
  final PlaybackTimeline? timeline;
}

/// Collection model; RemoteCollection persists operations through Nexus.
class HypnosisCollection extends ChangeNotifier {
  HypnosisCollection(this.desires, this.tapes, this.sampleStory);
  final List<Desire> desires;
  final List<Tape> tapes;
  final String sampleStory;
  int _next = 0;
  String newId() => 'new-${_next++}';
  Desire desire(String id) => desires.firstWhere((d) => d.id == id);
  List<Tape> forDesire(String id) =>
      tapes.where((t) => t.desireId == id).toList();

  Future<Desire> saveDesire(String title, String belief, {String? id}) async {
    if (id != null) {
      final d = desire(id);
      d.title = title;
      d.belief = belief;
      return d;
    }
    final d = Desire(id: newId(), title: title, belief: belief);
    desires.add(d);
    return d;
  }

  Future<Tape> createTape(String desireId, String title, String prompt) async {
    final tape = Tape(
      id: newId(),
      desireId: desireId,
      title: title,
      prompt: prompt,
      story: sampleStory,
    );
    tapes.add(tape);
    return tape;
  }

  Future<void> removeDesire(Desire item, {String? moveTo}) async {
    if (moveTo != null) {
      if (moveTo == item.id || !desires.any((d) => d.id == moveTo)) {
        throw ArgumentError('Choose another existing desire.');
      }
      for (final tape in forDesire(item.id)) {
        tape.desireId = moveTo;
      }
    } else {
      tapes.removeWhere((t) => t.desireId == item.id);
    }
    desires.remove(item);
  }
}
