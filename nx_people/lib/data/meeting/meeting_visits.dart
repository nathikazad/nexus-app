import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_people/data/sync/people_sync_providers.dart';
import 'package:nx_people/domain/person/person.dart';

PersonMeeting visitFromModel(Model model) {
  final events = model.relations?['Event'] ?? <Model>[];
  final places = model.relations?['Place'] ?? <Model>[];
  return PersonMeeting(
    id: model.id,
    name: events.isNotEmpty
        ? events.map((m) => m.name).join(' · ')
        : model.name.isNotEmpty
        ? model.name
        : places.map((m) => m.name).join(' · '),
    description: places.map((m) => m.name).join(' · '),
    startTime: model.attrDateTime('start_time'),
    startPrecision: model.attrString('start_precision') ?? 'datetime',
  );
}

// Goto records represent actual visits; the Event catalog includes events the
// user never attended. Goto isn't currently included in the People offline feed.
final meetingVisitsProvider = FutureProvider.autoDispose<List<PersonMeeting>>((
  ref,
) async {
  ref.watch(peopleDataGenerationProvider);
  final user = ref.watch(authProvider).value;
  if (user?.domainId == null) return [];
  final rows = await fetchKgqlModels(
    ref.watch(graphqlClientProvider),
    domainId: user!.requiredDomainId,
    filter: {'model_type': 'Goto'},
    struct: {
      'id': true,
      'name': true,
      'start_time': true,
      'start_precision': true,
      'Event': {'id': true, 'name': true},
      'Place': {'id': true, 'name': true},
    },
  );
  return rows.map(visitFromModel).where((m) => m.startTime != null).toList();
});
