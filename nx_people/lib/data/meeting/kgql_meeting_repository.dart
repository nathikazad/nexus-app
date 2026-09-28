import 'package:nx_people/data/sync/people_data_repository.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_people/domain/meeting/meeting_repository.dart';

class KgqlMeetingRepository implements MeetingRepository {
  KgqlMeetingRepository({required GraphQLClient client, this.data})
    : _client = client;

  final PeopleDataRepository? data;
  final GraphQLClient _client;

  @override
  Future<int> create(MeetingDraft draft) {
    return data?.set(meetingCreateRequest(draft)) ??
        setKgqlModel(_client, meetingCreateRequest(draft));
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
