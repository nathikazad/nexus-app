import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_people/data/person/person_mapper.dart';

void main() {
  group('personFromModel meetings', () {
    test('maps image_url onto the person photo field', () {
      final person = Model(
        id: 1,
        name: 'Ada Lovelace',
        modelTypeId: 1,
        attributes: const {
          'image_url': '/person_image_files/1/linkedin/ada/profile.jpg',
        },
      );

      final mapped = personFromModel(person);

      expect(mapped.imageUrl, '/person_image_files/1/linkedin/ada/profile.jpg');
    });

    test('splits attended and planned Meet rows from Plannable fields', () {
      final person = Model(
        id: 1,
        name: 'Ada Lovelace',
        modelTypeId: 1,
        relations: {
          'Meeting': [Model(id: 2, name: 'Legacy Review', modelTypeId: 2)],
          'Meet': [
            Model(
              id: 3,
              name: 'Past Sync',
              modelTypeId: 3,
              attributes: const {
                'start_time': '2026-07-01T09:00:00',
                'planning_status': 'attended',
              },
            ),
            Model(
              id: 4,
              name: 'Future Planning',
              modelTypeId: 3,
              attributes: const {
                'scheduled_start_time': '2026-07-10T09:00:00',
                'planning_status': 'planned',
              },
            ),
            Model(
              id: 5,
              name: 'Cancelled Planning',
              modelTypeId: 3,
              attributes: const {
                'scheduled_start_time': '2026-07-11T09:00:00',
                'planning_status': 'cancelled',
              },
            ),
            Model(
              id: 6,
              name: 'Default Attended',
              modelTypeId: 3,
              attributes: const {'scheduled_start_time': '2026-07-12T09:00:00'},
            ),
          ],
        },
      );

      final mapped = personFromModel(person);

      expect(mapped.meetings, ['Legacy Review', 'Past Sync']);
      expect(mapped.planned, ['Future Planning']);
    });
  });
}
