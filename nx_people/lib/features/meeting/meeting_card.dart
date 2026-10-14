import 'package:flutter/material.dart';
import 'package:nx_people/domain/person/person.dart';
import 'package:nx_people/features/meeting/meeting_detail_page.dart';

String meetingDateLabel(BuildContext context, PersonMeeting meeting) {
  final time = meeting.displayDate;
  if (time == null) return 'Date unavailable';
  final locale = MaterialLocalizations.of(context);
  if (meeting.isDateOnly) return locale.formatMediumDate(time);
  return '${locale.formatMediumDate(time)} · ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(time), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}

class MeetingCard extends StatelessWidget {
  const MeetingCard({super.key, required this.meeting});
  final PersonMeeting meeting;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = meeting.displayDate;
    final locale = MaterialLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openMeeting(context, meeting),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Column(
                  children: [
                    Text(
                      date == null
                          ? '—'
                          : const [
                              'JAN',
                              'FEB',
                              'MAR',
                              'APR',
                              'MAY',
                              'JUN',
                              'JUL',
                              'AUG',
                              'SEP',
                              'OCT',
                              'NOV',
                              'DEC',
                            ][date.month - 1],
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (date != null)
                      Text(
                        '${date.day}'.padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: .5),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meeting.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        date == null
                            ? 'Date unavailable'
                            : meeting.isDateOnly
                            ? locale.formatMediumDate(date)
                            : locale.formatTimeOfDay(
                                TimeOfDay.fromDateTime(date),
                                alwaysUse24HourFormat:
                                    MediaQuery.alwaysUse24HourFormatOf(context),
                              ),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (meeting.description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          meeting.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.onSurfaceVariant,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
