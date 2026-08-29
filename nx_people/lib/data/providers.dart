import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart'
    show
        imageBaseUrlProvider,
        nexusHttpClientProvider,
        nexusRequestHeadersProvider,
        userIdProvider;
import 'package:nx_db/riverpod.dart';
import 'package:nx_people/data/log/kgql_log_repository.dart';
import 'package:nx_people/data/log/log_image_upload_service.dart';
import 'package:nx_people/data/meeting/kgql_meeting_repository.dart';
import 'package:nx_people/data/person/kgql_people_repository.dart';
import 'package:nx_people/data/person/person_schema_provider.dart';
import 'package:nx_people/domain/log/daily_log.dart';
import 'package:nx_people/domain/log/log_repository.dart';
import 'package:nx_people/domain/meeting/meeting_repository.dart';
import 'package:nx_people/domain/person/person.dart';
import 'package:nx_people/domain/person/person_query.dart';

class PeopleImageConfig {
  const PeopleImageConfig({required this.baseUrl, required this.headers});

  final String baseUrl;
  final Map<String, String> headers;
}

final peopleImageConfigProvider = Provider<PeopleImageConfig?>((ref) {
  final baseUrl = ref.watch(imageBaseUrlProvider);
  final userId = ref.watch(userIdProvider);
  if (baseUrl == null || baseUrl.trim().isEmpty || userId == null) {
    return null;
  }
  final headers = ref.watch(nexusRequestHeadersProvider).value;
  if (headers == null) return null;
  return PeopleImageConfig(baseUrl: baseUrl, headers: headers);
});

final peopleRepositoryProvider = Provider<PersonRepository>((ref) {
  return KgqlPeopleRepository(
    client: ref.watch(graphqlClientProvider),
    loadPersonSchema: () => ref.read(personSchemaProvider.future),
  );
});

final logRepositoryProvider = Provider<LogRepository>((ref) {
  return KgqlLogRepository(client: ref.watch(graphqlClientProvider));
});

final meetingRepositoryProvider = Provider<MeetingRepository>((ref) {
  return KgqlMeetingRepository(client: ref.watch(graphqlClientProvider));
});

final logImageUploadServiceProvider = Provider<LogImageUploadService?>((ref) {
  final baseUrl = ref.watch(imageBaseUrlProvider);
  final client = ref.watch(nexusHttpClientProvider);
  if (baseUrl == null || baseUrl.trim().isEmpty || client == null) return null;
  return LogImageUploadService(baseUrl: baseUrl, client: client);
});

final dailyLogsForDayProvider = FutureProvider.family<List<DailyLog>, DateTime>(
  (ref, day) => ref.watch(logRepositoryProvider).listForCalendarDay(day),
);

final recentPeopleProvider = FutureProvider<List<Person>>(
  (ref) => ref.watch(peopleRepositoryProvider).listRecent(limit: 20),
);

final pinnedPeopleProvider = FutureProvider<List<Person>>(
  (ref) => ref.watch(peopleRepositoryProvider).listPinned(limit: 20),
);

final followUpPeopleProvider = FutureProvider<List<Person>>(
  (ref) => ref.watch(peopleRepositoryProvider).listFollowUp(limit: 20),
);

final peopleTagSystemsProvider = FutureProvider<List<PeopleTagSystem>>(
  (ref) => ref.watch(peopleRepositoryProvider).listTagSystems(),
);

final personByIdProvider = FutureProvider.family<Person?, int>(
  (ref, id) => ref.watch(peopleRepositoryProvider).getById(id),
);

final companiesProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(peopleRepositoryProvider).listCompanies(),
);

final meetingsProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(peopleRepositoryProvider).listMeetings(),
);

final plannedProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(peopleRepositoryProvider).listPlanned(),
);
