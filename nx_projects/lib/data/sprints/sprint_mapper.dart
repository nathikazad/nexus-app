import 'package:intl/intl.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_projects/data/sprints/sprint_attr_keys.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/sprint/sprint_state.dart';

SprintState _stateFromAttr(String? raw) {
  return switch (raw) {
    'completed' => SprintState.done,
    'active' => SprintState.active,
    'planned' => SprintState.planned,
    _ => SprintState.planned,
  };
}

String _stateToAttr(SprintState s) {
  return switch (s) {
    SprintState.done => 'completed',
    SprintState.active => 'active',
    SprintState.planned => 'planned',
  };
}

String _badgeFor(SprintState s) {
  return switch (s) {
    SprintState.done => 'done',
    SprintState.active => 'active',
    SprintState.planned => 'planned',
  };
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _isoNoon(String ymd) {
  final d = DateTime.tryParse('${ymd}T12:00:00') ?? DateTime.now();
  return DateTime(d.year, d.month, d.day, 12).toIso8601String();
}

String _sprintEndYmd(Sprint s) {
  final start = DateTime.tryParse('${s.start}T12:00:00') ?? DateTime.now();
  final length = s.length < 1 ? 1 : s.length;
  return _ymd(start.add(Duration(days: length - 1)));
}

Sprint sprintFromModel(Model m) {
  final start = m.attrDateTime(kSprintAttrStartDate) ?? DateTime.now();
  final end = m.attrDateTime(kSprintAttrEndDate) ?? start;
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);
  final length = endDay.difference(startDay).inDays + 1;
  final dFmt = DateFormat('MMM d');
  final yNow = start.year == end.year;
  final dates = yNow
      ? '${dFmt.format(start)} – ${dFmt.format(end)}'
      : '${dFmt.format(start)} – ${dFmt.format(end)} ${end.year}';

  final statusRaw = m.attrString(kSprintAttrStatus);
  final state = _stateFromAttr(statusRaw);

  return Sprint(
    id: m.id,
    name: m.name,
    dates: dates,
    badge: _badgeFor(state),
    start: _ymd(startDay),
    length: length,
    capH: m.attrDouble(kSprintAttrAllocatedHours) ?? 0,
    state: state,
    goal: m.attrString(kSprintAttrGoal) ?? '',
    retro: '',
    dayNotes: const {},
  );
}

List<SetModelAttribute> setModelAttributesForSprintCreate(Sprint s) {
  return [
    SetModelAttribute(key: kSprintAttrName, value: s.name),
    SetModelAttribute(key: kSprintAttrStartDate, value: _isoNoon(s.start)),
    SetModelAttribute(
      key: kSprintAttrEndDate,
      value: _isoNoon(_sprintEndYmd(s)),
    ),
    SetModelAttribute(key: kSprintAttrGoal, value: s.goal),
    SetModelAttribute(key: kSprintAttrStatus, value: _stateToAttr(s.state)),
    SetModelAttribute(key: kSprintAttrAllocatedHours, value: s.capH),
  ];
}

SetModelRequest setModelRequestForCreateSprint(Sprint s) {
  return SetModelRequest(
    modelType: kSprintModelTypeName,
    name: s.name,
    attributes: setModelAttributesForSprintCreate(s),
  );
}

List<SetModelAttribute> setModelAttributesForSprintUpdate(Sprint s) {
  return [
    SetModelAttribute(key: kSprintAttrName, value: s.name),
    SetModelAttribute(key: kSprintAttrGoal, value: s.goal),
    SetModelAttribute(key: kSprintAttrStatus, value: _stateToAttr(s.state)),
    SetModelAttribute(key: kSprintAttrAllocatedHours, value: s.capH),
  ];
}

SetModelRequest setModelRequestForUpdateSprint(Sprint s) {
  return SetModelRequest(
    id: s.id,
    name: s.name,
    attributes: setModelAttributesForSprintUpdate(s),
  );
}
