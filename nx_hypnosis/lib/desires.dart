import 'dart:convert';
import 'package:flutter/services.dart';

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
  });
  final String id;
  String desireId;
  String title;
  String story;
  String prompt;
  String? audioAsset;
}

/// Temporary demo collection. No KGQL calls or persistent storage.
class HypnosisCollection {
  HypnosisCollection(this.desires, this.tapes, this.sampleStory);
  final List<Desire> desires;
  final List<Tape> tapes;
  final String sampleStory;
  int _next = 0;
  String newId() => 'new-${_next++}';
  Desire desire(String id) => desires.firstWhere((d) => d.id == id);
  List<Tape> forDesire(String id) =>
      tapes.where((t) => t.desireId == id).toList();

  static Future<HypnosisCollection> load() async {
    final raw =
        jsonDecode(await rootBundle.loadString('assets/desires.json')) as List;
    final story = await rootBundle.loadString('assets/story.txt');
    return HypnosisCollection(
      raw
          .map(
            (d) => Desire(id: d['id'], title: d['title'], belief: d['belief']),
          )
          .toList(),
      [
        Tape(
          id: 'sample',
          desireId: 'wealth',
          title: 'Abundance through helping others',
          story: story,
          audioAsset: 'assets/hypnotizer.mp3',
        ),
      ],
      story,
    );
  }

  void removeDesire(Desire item, {String? moveTo}) {
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
