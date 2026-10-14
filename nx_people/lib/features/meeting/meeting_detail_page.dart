import 'package:nx_people/features/assistant/people_assistant.dart';
import 'package:nx_people/core/theme/app_theme.dart';
import 'package:nx_people/features/meeting/meeting_card.dart';
import 'package:nx_people/features/meeting/meeting_audio_player.dart';
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
      floatingActionButton: PeopleAssistantButton(
        selection: PeopleAssistantContext(
          kind: 'Meet',
          id: meeting.id,
          name: meeting.name,
        ),
      ),
      appBar: AppBar(
        title: const Text(
          'Conversation',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      body: transcript.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Unable to load this transcript.')),
        data: (state) => ListView(
          key: PageStorageKey('meeting-${meeting.id}'),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
          children: [
            Text(
              meetingDateLabel(context, meeting),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(meeting.name, style: peopleEditorialTitle(32)),
            const SizedBox(height: 20),
            if (meeting.description.isNotEmpty) ...[
              Text(
                meeting.description,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Icon(
                  state.connected
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.connected
                        ? 'Updates automatically'
                        : 'Reconnecting · showing saved transcript',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Divider(height: 1),
            const SizedBox(height: 24),
            if (state.rows.isEmpty)
              Text(
                state.connected
                    ? 'No recording attached to this meeting.'
                    : 'No saved transcript yet.',
              ),
            for (final row in state.rows) ...[
              if ((row['audio_status'] == 'complete' ||
                      row['audio_status'] == 'uploaded') &&
                  row['device_id'] is String &&
                  row['file_id'] is String)
                MeetingAudioPlayer(
                  key: ValueKey('${meeting.id}-${row['file_id']}'),
                  deviceId: row['device_id'] as String,
                  fileId: row['file_id'] as String,
                ),
              const SizedBox(height: 20),
              const Text(
                'TRANSCRIPT',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                row['status'] == 'complete'
                    ? 'Transcript complete'
                    : row['audio_status'] == 'uploaded'
                    ? 'Finishing transcription…'
                    : 'Recording • transcript in progress',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                (row['text'] as String? ?? '').isEmpty
                    ? 'Waiting for speech…'
                    : row['text'] as String,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.8, letterSpacing: .1),
              ),
              const SizedBox(height: 28),
            ],
          ],
        ),
      ),
    );
  }
}
