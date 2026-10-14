import 'package:nx_people/data/meeting/meeting_time.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_people/data/sync/people_sync_providers.dart';
import 'package:nx_people/domain/person/person.dart';

final allMeetingsProvider = FutureProvider<List<PersonMeeting>>((ref) async {
  ref.watch(peopleDataGenerationProvider);
  final data = ref.watch(peopleDataRepositoryProvider);
  final rows = data != null
      ? await data.models('Meet')
      : await fetchKgqlModels(
          ref.watch(graphqlClientProvider),
          filter: {'model_type': 'Meet'},
          struct: {
            'id': true,
            'name': true,
            'description': true,
            'created_at': true,
            'start_time': true,
            'start_precision': true,
          },
        );
  final meetings = rows
      .map(
        (m) => PersonMeeting(
          id: m.id,
          name: m.name.isEmpty ? 'Conversation' : m.name,
          description: m.description ?? '',
          startTime: m.attrDateTime('start_time'),
          startPrecision:
              m.attributes?['start_precision']?.toString() ?? 'datetime',
          createdAt: parseMeetingCreatedAt(m.createdAt),
        ),
      )
      .toList();
  meetings.sort(
    (a, b) => (b.startTime ?? b.createdAt ?? DateTime(0)).compareTo(
      a.startTime ?? a.createdAt ?? DateTime(0),
    ),
  );
  return meetings;
});
