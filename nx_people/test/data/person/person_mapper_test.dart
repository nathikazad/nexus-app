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

    test('maps LinkedIn suggestion JSON onto person suggestions', () {
      final person = Model(
        id: 1,
        name: 'Ada Lovelace',
        modelTypeId: 1,
        attributes: const {
          'suggestion': {
            'work': [
              {
                'company': 'Example Corp',
                'title': 'Founder',
                'start_date': '2020-01-01T00:00:00Z',
                'end_date': null,
                'notes': 'Imported from LinkedIn.',
                'suggestions': [
                  {'name': 'Example Corp', 'id': 123, 'percentage': 94},
                ],
              },
            ],
            'education': [
              {
                'school': 'Example University',
                'type': 'master',
                'start_date': '2016-01-01T00:00:00Z',
                'end_date': '2018-01-01T00:00:00Z',
                'notes': '',
                'suggestions': [],
              },
            ],
          },
        },
      );

      final mapped = personFromModel(person);

      expect(mapped.suggestions.work.single.company, 'Example Corp');
      expect(mapped.suggestions.work.single.candidates.single.id, 123);
      expect(mapped.suggestions.education.single.school, 'Example University');
    });

    test('maps relation-backed background separately from suggestions', () {
      final person = Model(
        id: 1,
        name: 'Ada Lovelace',
        modelTypeId: 1,
        relations: {
          'School': [
            Model(
              id: 3,
              name: 'University of London',
              description: 'Accepted education relation.',
              modelTypeId: 3,
            ),
          ],
        },
        relationsList: [
          Relation(
            relationId: 2,
            modelId: 2,
            modelType: 'Company',
            name: 'Analytical Engines Inc',
            description: 'Accepted company relation.',
            relationName: 'work_for',
          ),
        ],
        attributes: const {
          'suggestion': {
            'work': [
              {
                'company': 'Unresolved Corp',
                'title': 'Advisor',
                'suggestions': [],
              },
            ],
          },
        },
      );

      final mapped = personFromModel(person);

      expect(mapped.workRelations.single.name, 'Analytical Engines Inc');
      expect(
        mapped.workRelations.single.description,
        'Accepted company relation.',
      );
      expect(mapped.educationRelations.single.name, 'University of London');
      expect(mapped.suggestions.work.single.company, 'Unresolved Corp');
    });

    test('maps named Company relations into work and education buckets', () {
      final person = Model(
        id: 1,
        name: 'Ollie Rubens',
        modelTypeId: 1,
        relationsList: [
          Relation(
            relationId: 10,
            modelId: 4683,
            modelType: 'Company',
            name: 'BootLoop',
            relationName: 'work_for',
            relationAttributes: const {
              'title': 'Head of Sales',
              'start_date': '2026-01-01T00:00:00Z',
              'notes': 'Full-time',
            },
          ),
          Relation(
            relationId: 11,
            modelId: 4686,
            modelType: 'Company',
            name: 'University of Cambridge',
            relationName: 'study_at',
            relationAttributes: const {
              'type': 'bachelor',
              'start_date': '2009-01-01T00:00:00Z',
              'end_date': '2012-01-01T00:00:00Z',
            },
          ),
        ],
      );

      final mapped = personFromModel(person);

      expect(mapped.workRelations.single.name, 'BootLoop');
      expect(mapped.workRelations.single.relationName, 'work_for');
      expect(mapped.workRelations.single.attributes['title'], 'Head of Sales');
      expect(mapped.educationRelations.single.name, 'University of Cambridge');
      expect(mapped.educationRelations.single.relationName, 'study_at');
      expect(mapped.educationRelations.single.attributes['type'], 'bachelor');
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
