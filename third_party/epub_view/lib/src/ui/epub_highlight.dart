import 'package:flutter/material.dart';
import 'paged_content.dart' show EpubLocation;

/// Source-anchored annotation; storage identity/versioning belongs to the app.
class EpubHighlight {
  const EpubHighlight(
      {required this.id,
      required this.start,
      required this.end,
      required this.text,
      this.color = 0xffffe082});
  final String id;
  final EpubLocation start;
  final EpubLocation end;
  final String text;
  final int color;

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toJson(),
        'end': end.toJson(),
        'text': text,
        'color': color
      };

  static EpubHighlight? fromJson(dynamic value) {
    if (value is! Map || value['deleted'] == true) return null;
    final start = EpubLocation.fromJson(value['start']);
    final end = EpubLocation.fromJson(value['end']);
    if (start == null ||
        end == null ||
        value['id'] is! String ||
        value['text'] is! String ||
        value['color'] is! int ||
        compareEpubLocations(start, end) >= 0) return null;
    return EpubHighlight(
        id: value['id'],
        start: start,
        end: end,
        text: value['text'],
        color: value['color']);
  }

  Color get paintColor => Color(color).withValues(alpha: .35);
}

int compareEpubLocations(EpubLocation a, EpubLocation b) {
  final block = a.block.compareTo(b.block);
  if (block != 0) return block;
  final run = a.run.compareTo(b.run);
  return run != 0 ? run : a.character.compareTo(b.character);
}
