import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';

class NetworkingEvent {
  const NetworkingEvent(
    this.name,
    this.description,
    this.startTime, {
    this.location = '',
    this.url,
  });
  final String name, description, location;
  final DateTime? startTime;
  final Uri? url;

  factory NetworkingEvent.fromModel(Model model) {
    final candidate = Uri.tryParse(model.attrString('url') ?? '');
    return NetworkingEvent(
      model.name,
      model.description ?? '',
      model.attrDateTime('start_time'),
      location: (model.relations?['Place'] ?? [])
          .map((m) => m.name)
          .join(' · '),
      url:
          candidate != null &&
              ['https', 'http'].contains(candidate.scheme) &&
              candidate.host.isNotEmpty
          ? candidate
          : null,
    );
  }
}

final networkingEventsProvider =
    FutureProvider.autoDispose<List<NetworkingEvent>>((ref) async {
      final user = ref.watch(authProvider).value;
      if (user?.domainId == null) return [];
      final rows = await fetchKgqlModels(
        ref.watch(graphqlClientProvider),
        domainId: user!.requiredDomainId,
        // Events exist independently of attendance; never filter by Goto/Meet.
        filter: {'model_type': 'Event'},
        struct: {
          'id': true,
          'name': true,
          'description': true,
          'start_time': true,
          'url': true,
          'Place': {'id': true, 'name': true},
        },
      );
      return rows.map(NetworkingEvent.fromModel).toList();
    });

DateTime mondayOf(DateTime day) =>
    DateTime(day.year, day.month, day.day - day.weekday + 1);

List<NetworkingEvent> eventsOnDay(List<NetworkingEvent> events, DateTime day) {
  return events.where((event) {
    final time = event.startTime?.toLocal();
    return time != null &&
        time.year == day.year &&
        time.month == day.month &&
        time.day == day.day;
  }).toList()..sort((a, b) => a.startTime!.compareTo(b.startTime!));
}
