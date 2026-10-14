import 'package:nx_people/data/meeting/meeting_visits.dart';
import 'package:nx_people/features/meeting/week_navigator.dart';
import 'package:nx_people/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_people/data/meeting/meeting_list.dart';
import 'package:nx_people/domain/person/person.dart';
import 'package:nx_people/features/meeting/meeting_detail_page.dart';

List<PersonMeeting> meetingsOnDay(List<PersonMeeting> rows, DateTime day) =>
    rows.where((m) {
      final time = m.displayDate;
      return time != null &&
          time.year == day.year &&
          time.month == day.month &&
          time.day == day.day;
    }).toList()..sort((a, b) => a.displayDate!.compareTo(b.displayDate!));

class MeetingsPage extends ConsumerStatefulWidget {
  const MeetingsPage({super.key, this.onCreate});
  final VoidCallback? onCreate;
  @override
  ConsumerState<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends ConsumerState<MeetingsPage> {
  DateTime day = DateUtils.dateOnly(DateTime.now());
  late DateTime week = DateTime(day.year, day.month, day.day - day.weekday + 1);

  void moveWeek(int delta) {
    setState(() {
      day = DateTime(day.year, day.month, day.day + 7 * delta);
      week = DateTime(day.year, day.month, day.day - day.weekday + 1);
    });
  }

  Future<void> chooseDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null && mounted) {
      setState(() {
        day = value;
        week = DateTime(value.year, value.month, value.day - value.weekday + 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 16, 24),
        child: Row(
          children: [
            Expanded(child: Text('Meetings', style: peopleEditorialTitle(30))),
            IconButton(
              tooltip: 'Choose date',
              onPressed: chooseDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 20),
            ),
            if (widget.onCreate != null)
              IconButton(
                tooltip: 'Add meeting',
                onPressed: widget.onCreate,
                icon: const Icon(Icons.add_circle_outline, size: 24),
              ),
          ],
        ),
      ),
      WeekNavigator(
        week: week,
        onPrevious: () => moveWeek(-1),
        onNext: () => moveWeek(1),
        onToday: () => setState(() {
          day = DateUtils.dateOnly(DateTime.now());
          week = DateTime(day.year, day.month, day.day - day.weekday + 1);
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
            .watch(allMeetingsProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(allMeetingsProvider),
                  child: const Text('Could not load meetings. Retry'),
                ),
              ),
              data: (rows) {
                final visits = ref.watch(meetingVisitsProvider);
                final visitRows = visits.asData?.value ?? <PersonMeeting>[];
                final visitIds = visitRows.map((m) => m.id).toSet();
                final meetings = meetingsOnDay([...rows, ...visitRows], day);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  children: [
                    if (visits.isLoading) const LinearProgressIndicator(),
                    if (visits.hasError)
                      TextButton(
                        onPressed: () => ref.invalidate(meetingVisitsProvider),
                        child: const Text('Could not load visits. Retry'),
                      ),
                    if (meetings.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'No meetings or visits on this day',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    for (var i = 0; i < meetings.length; i++)
                      _TimelineMeeting(
                        meeting: meetings[i],
                        isVisit: visitIds.contains(meetings[i].id),
                      ),
                  ],
                );
              },
            ),
      ),
    ],
  );
}

class _TimelineMeeting extends StatelessWidget {
  const _TimelineMeeting({required this.meeting, required this.isVisit});
  final PersonMeeting meeting;
  final bool isVisit;

  @override
  Widget build(BuildContext context) {
    final time = meeting.displayDate!;
    final label = meeting.isDateOnly
        ? 'Time unspecified'
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(time),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          );
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Material(
            color: isVisit ? colors.secondaryContainer : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isVisit ? colors.secondary : AppColors.line,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: isVisit ? null : () => openMeeting(context, meeting),
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isVisit)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.place_outlined,
                                size: 16,
                                color: colors.onSecondaryContainer,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Visit',
                                style: TextStyle(
                                  color: colors.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        meeting.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isVisit
                              ? colors.onSecondaryContainer
                              : AppColors.text,
                        ),
                      ),
                      if (meeting.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          meeting.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: isVisit
                                ? colors.onSecondaryContainer
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
