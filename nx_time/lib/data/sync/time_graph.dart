/// Local KGQL projections for NX Time's known read shapes. Unsupported filters
/// fail explicitly instead of returning a misleading partial result.
class TimeGraph {
  TimeGraph(this.rows, {this.aliases = const {}});
  final Map<int, int> aliases;
  final List<Map<String, dynamic>> rows;
  bool isType(Map row, String type) =>
      row['kind'] == type || (row['families'] as List? ?? []).contains(type);
  Map<String, dynamic>? get(int id) =>
      rows.where((r) => r['id'] == (aliases[id] ?? id)).firstOrNull;

  List<Map<String, dynamic>> neighbors(Map<String, dynamic> row) {
    final edges = <Map<String, dynamic>>[];
    for (final raw in row['relations'] as List? ?? []) {
      final edge = Map<String, dynamic>.from(raw as Map);
      edges.add({...edge, 'relation': 'child'});
    }
    for (final other in rows) {
      for (final raw in other['relations'] as List? ?? []) {
        final edge = Map<String, dynamic>.from(raw as Map);
        if (edge['model_id'] == row['id'])
          edges.add({
            ...edge,
            'model_id': other['id'],
            'model_type': other['kind'],
            'name': other['name'],
            'relation': 'parent',
          });
      }
    }
    return edges;
  }

  bool matches(Map<String, dynamic> row, Map filter) {
    if (filter.keys.any(
      (k) => !{
        'model_type',
        'model_type_id',
        'filters',
        'relation_filters',
        'limit',
        'order_by',
      }.contains(k),
    )) {
      throw UnsupportedError('This filter requires an online query');
    }
    if (filter['model_type'] case final String type) {
      if (!isType(row, type)) return false;
    }
    if (filter['model_type_id'] != null &&
        filter['model_type_id'] != row['model_type_id'])
      return false;
    for (final f in filter['filters'] as List? ?? []) {
      final actual = row[f['key']];
      final expected = f['key'] == 'id'
          ? (aliases[f['value']] ?? f['value'])
          : f['value'];
      if (f['op'] == '=') {
        if (actual != expected) return false;
        continue;
      }
      if (actual == null || expected == null) return false;
      final comparison = actual is num && expected is num
          ? actual.compareTo(expected)
          : actual.toString().compareTo(expected.toString());
      final ok = switch (f['op']) {
        '>=' => comparison >= 0,
        '>' => comparison > 0,
        '<' => comparison < 0,
        '<=' => comparison <= 0,
        '!=' => actual != expected,
        _ => throw UnsupportedError('Unsupported offline filter ${f['op']}'),
      };
      if (!ok) return false;
    }
    for (final f in filter['relation_filters'] as List? ?? []) {
      if (!neighbors(row).any((e) {
        final target = get(e['model_id'] as int);
        return target != null &&
            matches(target, Map<String, dynamic>.from(f as Map));
      }))
        return false;
    }
    return true;
  }

  List<Map<String, dynamic>> query(Map filter, Map struct) {
    final selected = rows
        .where((r) => r['id'] != 0 && matches(r, filter))
        .toList();
    final order = filter['order_by'] as Map?;
    selected.sort((a, b) {
      final key = order?['key'] ?? 'id';
      final av = a[key], bv = b[key];
      final cmp = av is num && bv is num
          ? av.compareTo(bv)
          : '$av'.compareTo('$bv');
      return order?['direction'] == 'desc' ? -cmp : cmp;
    });
    return [
      for (final r in selected.take(filter['limit'] as int? ?? selected.length))
        project(r, struct),
    ];
  }

  Map<String, dynamic> project(
    Map<String, dynamic> row,
    Map struct, {
    int depth = 0,
  }) {
    final result = Map<String, dynamic>.from(row);
    final edges = neighbors(row);
    result['relations'] = edges;
    if (depth < 3)
      for (final entry in struct.entries) {
        if (entry.value is! Map ||
            entry.key == 'model_type' ||
            entry.key == 'attributes' ||
            entry.key == 'relations')
          continue;
        result[entry.key] = [
          for (final edge in edges)
            if (get(edge['model_id'] as int) case final target?)
              if (isType(target, entry.key as String))
                {
                  ...project(target, entry.value as Map, depth: depth + 1),
                  'relation': edge['relation'],
                },
        ];
      }
    return result;
  }

  Map<String, dynamic> calendar(
    DateTime from,
    DateTime until, {
    bool history = false,
  }) {
    final entries = <Map<String, dynamic>>[],
        current = <Map<String, dynamic>>[],
        unscheduled = <Map<String, dynamic>>[];
    DateTime? time(Map r, String k) =>
        DateTime.tryParse(r[k]?.toString() ?? '');
    bool overlaps(DateTime? start, DateTime? end) =>
        start != null &&
        start.isBefore(until) &&
        (end != null && end.isAfter(start)
            ? end.isAfter(from)
            : !start.isBefore(from));
    Map<String, dynamic> entry(
      Map<String, dynamic> r,
      String kind,
      DateTime? start,
      DateTime? end,
    ) => {
      'key': '$kind:${r['id']}:$start',
      'id': r['id'],
      'kind': kind,
      'model_type': r['kind'],
      'name': r['name'],
      'description': r['description'],
      'start': start?.toIso8601String(),
      'end': end?.toIso8601String(),
      'attributes': r,
      'links': [
        for (final edge in r['relations'] as List? ?? [])
          {
            'id': edge['model_id'],
            'name': get(edge['model_id'] as int)?['name'] ?? edge['name'],
            'model_type': edge['model_type'],
            'relation_name': edge['relation_name'],
          },
      ],
      'attendance': <Map<String, dynamic>>[],
    };
    for (final r in rows.where((r) => r['id'] != 0)) {
      if (isType(r, 'Person')) {
        final birthday = r['birthday']?.toString() ?? '';
        if (!RegExp(r'^(--|[0-9]{4}-)[0-9]{2}-[0-9]{2}$').hasMatch(birthday))
          continue;
        for (
          var day = DateTime(from.year, from.month, from.day);
          day.isBefore(until);
          day = DateTime(day.year, day.month, day.day + 1)
        ) {
          final md =
              '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          final leap = DateTime(day.year, 3, 0).day == 29;
          if (birthday.endsWith(md) ||
              birthday.endsWith('02-29') && !leap && md == '02-28')
            entries.add(entry(r, 'birthday', day, null));
        }
        continue;
      }
      final kind = isType(r, 'Task')
          ? 'task'
          : isType(r, 'Event')
          ? 'event'
          : isType(r, 'Action')
          ? 'action'
          : null;
      if (kind == null) continue;
      final start = kind == 'task'
          ? time(r, 'due_at')
          : kind == 'event'
          ? time(r, 'start_time') ?? time(r, 'end_time')
          : history
          ? time(r, 'start_time')
          : time(r, 'scheduled_start_time') ??
                time(r, 'scheduled_end_time') ??
                time(r, 'start_time');
      final end = kind == 'task'
          ? null
          : kind == 'event' || history
          ? time(r, 'end_time')
          : time(r, 'scheduled_start_time') != null
          ? time(r, 'scheduled_end_time')
          : time(r, 'end_time');
      final e = entry(r, kind, start, end);
      if (kind == 'task' &&
          ['todo', 'progress'].contains(r['status'] ?? 'todo')) {
        if (start == null || start.isBefore(until)) current.add(e);
        if (start == null) unscheduled.add(e);
      }
      if (history && kind == 'task' && overlaps(time(r, 'completed_at'), null))
        entries.add(entry(r, 'completion', time(r, 'completed_at'), null));
      if (!overlaps(start, end)) continue;
      if (kind == 'event') {
        e['attendance'] = [
          for (final g in rows)
            if (g['kind'] == 'Goto' &&
                (g['relations'] as List? ?? []).any(
                  (l) =>
                      l['relation_name'] == 'to_event' &&
                      l['model_id'] == r['id'],
                ))
              entry(
                g,
                'action',
                time(g, 'scheduled_start_time'),
                time(g, 'scheduled_end_time'),
              ),
        ];
      }
      entries.add(e);
    }
    if (!history) {
      final eventIds = entries
          .where((e) => e['kind'] == 'event')
          .map((e) => e['id'])
          .toSet();
      entries.removeWhere(
        (e) =>
            e['model_type'] == 'Goto' &&
            (e['links'] as List).any(
              (l) =>
                  l['relation_name'] == 'to_event' &&
                  eventIds.contains(l['id']),
            ),
      );
    }
    entries.sort(
      (a, b) => (a['start'] as String).compareTo(b['start'] as String),
    );
    return {
      'entries': entries,
      'current_tasks': current,
      'unscheduled': unscheduled,
    };
  }
}
