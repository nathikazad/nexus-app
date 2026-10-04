/// One normalized graph; app presentation does not change wire data.
final class RecordGraph {
  RecordGraph(this.records, this.hashes);
  final Map<String, Map<String, dynamic>> records;
  final Map<String, String> hashes;
  Map<String, dynamic>? model(Object? id) => records['model:$id'];
  Map<String, dynamic> view(String app, String key) {
    final source = records[key]!;
    if (!key.startsWith('model:')) return {...source};
    final attrs = Map<String, dynamic>.from(source['attributes'] as Map? ?? {});
    final kind = (source['model_type'] as Map)['name'] as String;
    final flat = {...source, ...attrs};
    final relations = <Map<String, dynamic>>[];
    final neighbors = <Map<String, dynamic>>[];
    for (final raw in source['relations'] as List? ?? []) {
      final edge = Map<String, dynamic>.from(raw as Map);
      final target = model(edge['model_id']);
      if (target == null) continue;
      neighbors.add(target);
      relations.add({
        ...edge,
        'name': target['name'],
        'description': target['description'],
        'model_type': (target['model_type'] as Map)['name'],
        'related_attributes': target['attributes'] ?? {},
      });
    }
    final base = {...source, 'relations': relations, 'revision': hashes[key]};
    if (app == 'hypnosis') {
      final desire = relations
          .where(
            (r) =>
                r['relation_name'] == 'tape_desire' &&
                r['from_id'] == source['id'],
          )
          .firstOrNull;
      return {
        'id': source['id'],
        'kind': kind == 'Desire' ? 'desires' : 'tapes',
        'record': {
          'id': '${source['id']}',
          'title': source['name'],
          ...attrs,
          if (kind == 'Tape') 'desire_id': '${desire?['model_id']}',
        },
      };
    }
    if (app == 'time') {
      final families = (source['families'] as List? ?? []);
      return {
        ...flat,
        'kind': kind,
        'revision': hashes[key],
        'relations': relations
            .where((r) => r['from_id'] == source['id'])
            .toList(),
        if (families.contains('Task') && !attrs.containsKey('status'))
          'status': 'todo',
        if (families.contains('Plannable') &&
            !attrs.containsKey('planning_status'))
          'planning_status': 'attended',
      };
    }
    if (app == 'people') {
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final target in neighbors) {
        final type = (target['model_type'] as Map)['name'] as String;
        final value = {
          ...target,
          ...Map<String, dynamic>.from(target['attributes'] as Map? ?? {}),
        };
        (grouped[type] ??= []).add(value);
        for (final family
            in (target['families'] as List? ?? []).cast<String>()) {
          if (family != type) (grouped[family] ??= []).add(value);
        }
      }
      return {
        ...flat,
        'kind': kind,
        'revision': hashes[key],
        'relations': relations,
        ...grouped,
      };
    }
    if (app == 'expense') {
      final links = <Map<String, dynamic>>[];
      for (final entry in records.entries.where(
        (e) => e.key.startsWith('timeline:'),
      )) {
        final event = entry.value;
        for (final raw in event['links'] as List? ?? []) {
          final link = Map<String, dynamic>.from(raw as Map);
          if (link['model_id'] == source['id'])
            links.add({
              'id': link['id'],
              'event_id': event['event_id'],
              'event_time': event['event_time'],
              'event_type': event['event_type'],
              'source': event['source'],
              'payload': event['payload'],
            });
        }
      }
      return {...base, 'kind': 'model', 'timeline_links': links};
    }
    if (app == 'docs' || app == 'books') {
      final transcripts = [
        for (final target in neighbors)
          if ((target['model_type'] as Map)['name'] == 'Transcript')
            {
              'id': target['id'],
              'messages': (target['attributes'] as Map?)?['messages'],
            },
      ];
      final transcriptId = (attrs['book_file'] as Map?)?['transcript_id'];
      final epub = model(transcriptId);
      return {
        ...base,
        'transcripts': transcripts,
        if (transcriptId != null)
          'epub_transcript': epub == null
              ? null
              : {
                  'id': epub['id'],
                  'messages': (epub['attributes'] as Map?)?['messages'] ?? {},
                },
      };
    }
    return base;
  }
}
