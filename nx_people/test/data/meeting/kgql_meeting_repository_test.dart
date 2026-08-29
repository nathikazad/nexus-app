import 'package:flutter_test/flutter_test.dart';
import 'package:nx_people/data/meeting/kgql_meeting_repository.dart';
import 'package:nx_people/domain/meeting/meeting_repository.dart';

void main() {
  test('creates a Meet linked to the selected Person', () {
    final request = meetingCreateRequest(
      MeetingDraft(
        title: '  Coffee catch-up  ',
        description: '  Discussed hiring.  ',
        personId: 42,
        startedAt: DateTime(2026, 8, 29, 9, 30),
      ),
    ).toJson();

    expect(request['model_type'], 'Meet');
    expect(request['name'], 'Coffee catch-up');
    expect(request['description'], 'Discussed hiring.');
    expect(request['relations'], <Map<String, Object?>>[
      <String, Object?>{
        'model_type': 'Person',
        'relation_name': 'with_person',
        'link': <int>[42],
      },
    ]);
  });
}
