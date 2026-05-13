import 'dart:developer' as developer;

import 'package:nx_time/core/debug_flags.dart';
import 'package:nx_time/domain/action/action.dart';

/// One top-level row: the umbrella [Action] plus its displayed children for the day.
class UmbrellaRow {
  const UmbrellaRow({required this.umbrella, required this.children});

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

/// Builds umbrella rows from a flat same-day [Action] list using only `childActionIds` edges.
///
/// `childActionIds` is already directional (the mapper filters KGQL `relation == 'child'`),
/// so we trust it as-is. Two ties still need explicit handling:
///   * **2-cycle** — both `A → B` and `B → A` were created. Drop the edge whose
///     `parent.id > child.id` so exactly one direction wins (smaller id parents).
///   * **Multiple parents claim the same child** — the smallest parent id wins.
List<UmbrellaRow> foldDayActions(List<Action> dayActions) {
  const tag = '[nx_time fold]';
  if (kNxTimeTraceActionSemantics) {
    developer.log(
      '$tag begin inDay=${dayActions.length} '
      '(directional childActionIds; 2-cycles broken by parent.id < child.id)',
      name: 'nx_time.fold',
    );
  }

  final byId = {for (final a in dayActions) a.id: a};
  final dayIds = byId.keys.toSet();

  // Collect every (parent, child) edge that is fully in the day-set.
  final edges = <(int parent, int child)>{};
  for (final a in dayActions) {
    for (final cid in a.childActionIds) {
      if (cid == a.id) continue;
      if (!dayIds.contains(cid)) continue;
      edges.add((a.id, cid));
    }
  }

  final childToParent = <int, int>{};
  for (final e in edges) {
    final pid = e.$1;
    final cid = e.$2;
    // 2-cycle breaker: if the reverse edge also exists, keep only the direction
    // where parent.id < child.id.
    if (edges.contains((cid, pid)) && pid > cid) continue;
    final prev = childToParent[cid];
    if (prev == null || pid < prev) {
      childToParent[cid] = pid;
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
