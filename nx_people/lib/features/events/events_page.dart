import 'package:nx_people/features/meeting/week_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_people/data/meeting/meeting_time.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nx_people/core/theme/app_theme.dart';
import 'package:nx_people/data/meeting/networking_events.dart';

class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({super.key});
  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage> {
  DateTime day = DateUtils.dateOnly(DateTime.now());
  late DateTime week = mondayOf(day);
  void moveWeek(int delta) => setState(() {
    day = DateTime(day.year, day.month, day.day + delta * 7);
    week = mondayOf(day);
  });

  Future<void> openEvent(BuildContext context, Uri url) async {
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Show a retryable failure without changing the event.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open event page. Please retry.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: Text('Events', style: peopleEditorialTitle(30)),
      ),
      WeekNavigator(
        week: week,
        onPrevious: () => moveWeek(-1),
        onNext: () => moveWeek(1),
        onToday: () => setState(() {
          day = DateUtils.dateOnly(DateTime.now());
          week = mondayOf(day);
        }),
      ),
      WeekDays(
        week: week,
        day: day,
        onSelected: (value) => setState(() => day = value),
      ),
      const SizedBox(height: 28),
      Expanded(
        child: ref
            .watch(networkingEventsProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(networkingEventsProvider),
                  child: const Text('Could not load events. Retry'),
                ),
              ),
              data: (events) {
                final visible = eventsOnDay(events, day);
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(networkingEventsProvider.future),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    children: [
                      if (visible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Text(
                            'No events on this day',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      for (final event in visible)
                        _EventCard(
                          event: event,
                          onTap: event.url == null
                              ? null
                              : () => openEvent(context, event.url!),
                        ),
                    ],
                  ),
                );
              },
            ),
      ),
    ],
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, this.onTap});
  final NetworkingEvent event;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final time = event.startTime?.toLocal();
    final timeLabel = time == null
        ? null
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(time),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          );
    final description = event.description
        .replaceAll(RegExp(r'https?://\S+'), '')
        .trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          time == null ? 'TBA' : shortMonth(time).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.muted,
                          ),
                        ),
                        if (time != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${time.day}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (timeLabel != null || event.location.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            [
                              if (timeLabel != null) timeLabel,
                              if (event.location.isNotEmpty) event.location,
                              if (time != null &&
                                  time.year != DateTime.now().year)
                                '${time.year}',
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.north_east,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
