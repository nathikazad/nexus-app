import 'dart:developer' as developer;

import 'package:nx_time/core/debug_flags.dart';
import 'package:nx_time/domain/action/action.dart';

/// One top-level row: the umbrella [Action] plus its displayed children for the day.
class UmbrellaRow {
  const UmbrellaRow({
    required this.umbrella,
    required this.children,
  });

  final Action umbrella;

  /// Child [Action]s whose parent for this day is [umbrella], sorted by start time.
  final List<Action> children;
}

int _cmpStartThenId(Action a, Action b) {
  final sa = a.startTime;
  final sb = b.startTime;
  if (sa == null && sb == null) return a.id.compareTo(b.id);
  if (sa == null) return 1;
  if (sb == null) return -1;
  final c = sa.compareTo(sb);
  if (c != 0) return c;
  return a.id.compareTo(b.id);
}

int _typeRankForParentTieBreak(Action a) {
  switch (a.modelTypeName) {
    case 'Goto':
      return 0;
    case 'Workout':
      return 1;
    case 'Meet':
      return 2;
    default:
      return 10;
  }
}

bool _acceptDirectedEdge(Action parent, Action child) {
  if (parent.id == child.id) return false;

  final ps = parent.startTime;
  final pe = parent.endTime;
  final cs = child.startTime;
  final ce = child.endTime;

  // Prefer semantic direction based on time window containment.
  if (ps != null && pe != null && cs != null && ce != null) {
    final contains = !ps.isAfter(cs) && !pe.isBefore(ce);
    if (!contains) return false;

    // If windows are identical, pick a stable parent direction.
    final sameWindow = ps == cs && pe == ce;
    if (sameWindow) {
      final pr = _typeRankForParentTieBreak(parent);
      final cr = _typeRankForParentTieBreak(child);
      if (pr != cr) return pr < cr;
      return parent.id < child.id;
    }
    return true;
  }

  // Fallback when times are missing: keep one stable direction only.
  return parent.id < child.id;
}

/// Builds umbrella rows from a flat same-day [Action] list using only `childActionIds` edges.
///
/// If a child is claimed by multiple parents in the day-set, the **smallest parent id** wins.
List<UmbrellaRow> foldDayActions(List<Action> dayActions) {
  const tag = '[nx_time fold]';
  if (kNxTimeTraceActionSemantics) {
    developer.log(
      '$tag begin inDay=${dayActions.length} '
      '(childActionIds edges only; smallest parent id wins)',
      name: 'nx_time.fold',
    );
  }

  final byId = {for (final a in dayActions) a.id: a};
  final dayIds = byId.keys.toSet();

  final childToParent = <int, int>{};
  for (final a in dayActions) {
    for (final cid in a.childActionIds) {
      if (!dayIds.contains(cid)) continue;
      final candidate = byId[cid];
      if (candidate == null) continue;
      if (!_acceptDirectedEdge(a, candidate)) continue;
      final prev = childToParent[cid];
      if (prev == null || a.id < prev) {
        childToParent[cid] = a.id;
      }
    }
  }

  if (kNxTimeTraceActionSemantics) {
    final entries = childToParent.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    developer.log(
      '$tag child→parent (child id maps to claiming parent id): '
      '${entries.map((e) => '${e.key}←${e.value}').join(' ')}',
      name: 'nx_time.fold',
    );
    for (final a in dayActions) {
      developer.log(
        '$tag   id=${a.id} type=${a.modelTypeName} childActionIds=${a.childActionIds}',
        name: 'nx_time.fold',
      );
    }
  }

  bool isRoot(Action a) => !childToParent.containsKey(a.id);

  final roots = dayActions.where(isRoot).toList()..sort(_cmpStartThenId);

  if (kNxTimeTraceActionSemantics) {
    developer.log(
      '$tag roots (ids not listed as a child by another row): '
      '${roots.map((r) => '${r.id}:${r.modelTypeName}').join(', ')}',
      name: 'nx_time.fold',
    );
  }

  final rows = <UmbrellaRow>[];
  for (final root in roots) {
    final childIds = root.childActionIds.where((cid) {
      if (!dayIds.contains(cid)) return false;
      return childToParent[cid] == root.id;
    }).toList();

    final children = <Action>[];
    for (final cid in childIds) {
      final c = byId[cid];
      if (c != null) children.add(c);
    }
    children.sort(_cmpStartThenId);

    if (kNxTimeTraceActionSemantics) {
      final dropped = root.childActionIds.where((cid) {
        if (!dayIds.contains(cid)) return true;
        return childToParent[cid] != root.id;
      }).toList();
      developer.log(
        '$tag   umbrella id=${root.id} type=${root.modelTypeName} '
        'childIds_kept=$childIds childCount=${children.length} '
        'childIds_dropped_not_claimed_here=$dropped',
        name: 'nx_time.fold',
      );
    }

    rows.add(UmbrellaRow(umbrella: root, children: children));
  }

  return rows;
}
