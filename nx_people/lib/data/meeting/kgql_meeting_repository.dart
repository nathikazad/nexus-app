import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_people/domain/meeting/meeting_repository.dart';

class KgqlMeetingRepository implements MeetingRepository {
  KgqlMeetingRepository({required GraphQLClient client}) : _client = client;

  final GraphQLClient _client;

  @override
  Future<int> create(MeetingDraft draft) {
    return setKgqlModel(_client, meetingCreateRequest(draft));
  }
}

SetModelRequest meetingCreateRequest(MeetingDraft draft) {
  final title = draft.title.trim();
  if (title.isEmpty) {
    throw ArgumentError('A meeting needs a title.');
  }
  return SetModelRequest(
    modelType: 'Meet',
    name: title,
    description: draft.description.trim(),
    attributes: <SetModelAttribute>[
      SetModelAttribute(
        key: 'start_time',
        value: draft.startedAt.toIso8601String(),
      ),
      SetModelAttribute(
        key: 'end_time',
        value: draft.startedAt.toIso8601String(),
      ),
    ],
    relations: <ModelRelation>[
      ModelRelation(
        modelType: 'Person',
        relationName: 'with_person',
        link: <int>[draft.personId],
      ),
    ],
  );
}
