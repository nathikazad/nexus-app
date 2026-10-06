import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_people/data/meeting/meeting_transcripts.dart';
import 'package:nx_people/domain/person/person.dart';

void openMeeting(BuildContext context, PersonMeeting meeting) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MeetingDetailPage(meeting: meeting),
    ),
  );
}

class MeetingDetailPage extends ConsumerWidget {
  const MeetingDetailPage({super.key, required this.meeting});
  final PersonMeeting meeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transcript = ref.watch(meetingTranscriptsProvider(meeting.id));
    return Scaffold(
      appBar: AppBar(title: Text(meeting.name)),
      body: transcript.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Unable to load this transcript.')),
        data: (state) => ListView(
          key: PageStorageKey('meeting-${meeting.id}'),
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              state.connected
                  ? 'Connected • updates automatically'
                  : 'Offline or reconnecting • showing saved transcript',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 20),
            if (state.rows.isEmpty)
              Text(
                state.connected
                    ? 'Waiting for recording audio…'
                    : 'No saved transcript yet.',
              ),
            for (final row in state.rows) ...[
              Text(
                row['status'] == 'complete'
                    ? 'Transcript complete'
                    : row['audio_status'] == 'uploaded'
                    ? 'Finishing transcription…'
                    : 'Recording • transcript in progress',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SelectableText(
                (row['text'] as String? ?? '').isEmpty
                    ? 'Waiting for speech…'
                    : row['text'] as String,
              ),
              const SizedBox(height: 28),
            ],
          ],
        ),
      ),
    );
  }
}
