import 'package:nx_time/domain/action/action.dart';

Action sampleAction({
  int id = 1,
  String name = 'Deep work',
  int modelTypeId = 10,
  String modelTypeName = 'Meet',
  DateTime? start,
  DateTime? end,
  String? description,
  List<int> childActionIds = const [],
  Map<int, int> relationIdByChildId = const {},
}) {
  final d = DateTime(2026, 4, 18);
  return Action(
    id: id,
    name: name,
    description: description,
    modelTypeId: modelTypeId,
    modelTypeName: modelTypeName,
    startTime: start ?? DateTime(d.year, d.month, d.day, 9, 0),
    endTime: end ?? DateTime(d.year, d.month, d.day, 11, 30),
    childActionIds: childActionIds,
    relationIdByChildId: relationIdByChildId,
  );
}
