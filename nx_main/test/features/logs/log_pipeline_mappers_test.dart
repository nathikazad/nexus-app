import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/features/logs/log_pipeline_mappers.dart';
import 'package:nexus_voice_assistant/features/logs/logs_providers.dart';
import 'package:nx_db/nx_db.dart';

void main() {
  group('agent run corrections', () {
    test('no correction gives null', () {
      final run = buildAgentRuns([
        _agentRow(id: '1', event: 'agent_run_start', seconds: 1),
        _agentRow(id: '2', event: 'agent_run_end', seconds: 2),
      ]).single;

      expect(run.correction, isNull);
    });

    test('non-empty payload correction parses with incorrect true', () {
      final run = buildAgentRuns([
        _agentRow(id: '1', event: 'agent_run_start', seconds: 1),
        _agentRow(
          id: '2',
          event: 'agent_run_end',
          seconds: 2,
          payload: const {
            'correction': {
              'note': '  wrong entity updated  ',
              'incorrect': true
            },
          },
        ),
      ]).single;

      expect(run.correction?.note, 'wrong entity updated');
      expect(run.correction?.incorrect, isTrue);
      expect(run.correction?.resolved, isFalse);
    });

    test('resolved correction parses true', () {
      final run = buildAgentRuns([
        _agentRow(id: '1', event: 'agent_run_start', seconds: 1),
        _agentRow(
          id: '2',
          event: 'agent_run_end',
          seconds: 2,
          payload: const {
            'correction': {
              'note': 'already handled',
              'incorrect': true,
              'resolved': true,
            },
          },
        ),
      ]).single;

      expect(run.correction?.resolved, isTrue);
    });

    test('empty correction note is ignored', () {
      final run = buildAgentRuns([
        _agentRow(id: '1', event: 'agent_run_start', seconds: 1),
        _agentRow(
          id: '2',
          event: 'agent_run_end',
          seconds: 2,
          payload: const {
            'correction': {'note': '   ', 'incorrect': true},
          },
        ),
      ]).single;

      expect(run.correction, isNull);
    });

    test('multiple correction payloads use latest parsed correction', () {
      final run = buildAgentRuns([
        _agentRow(
          id: '1',
          event: 'agent_run_start',
          seconds: 1,
          payload: const {
            'correction': {'note': 'old note', 'incorrect': true},
          },
        ),
        _agentRow(id: '2', event: 'agent_run_end', seconds: 2),
        _agentRow(
          id: '3',
          event: 'agent_model_response',
          seconds: 3,
          payload: const {
            'correction': {'note': 'new note', 'incorrect': true},
          },
        ),
      ]).single;

      expect(run.correction?.note, 'new note');
      expect(run.correction?.incorrect, isTrue);
    });

    test('canonical save target prefers agent_run_end, then latest row', () {
      final withEnd = buildAgentRuns([
        _agentRow(id: '1', event: 'agent_run_start', seconds: 1),
        _agentRow(
          id: '2',
          event: 'agent_run_end',
          seconds: 2,
          payload: const {'existing': true},
        ),
        _agentRow(id: '3', event: 'agent_tool_call', seconds: 3),
      ]).single;

      expect(withEnd.correctionTarget.id, '2');
      expect(withEnd.correctionTarget.payload['existing'], isTrue);

      final withoutEnd = buildAgentRuns([
        _agentRow(id: '1', event: 'agent_run_start', seconds: 1),
        _agentRow(id: '3', event: 'agent_tool_call', seconds: 3),
      ]).single;

      expect(withoutEnd.correctionTarget.id, '3');
    });

    test('save and clear payload helpers preserve other fields', () {
      final run = buildAgentRuns([
        _agentRow(id: '1', event: 'agent_run_start', seconds: 1),
        _agentRow(
          id: '2',
          event: 'agent_run_end',
          seconds: 2,
          payload: const {
            'existing': {'nested': true},
            'value': 7,
          },
        ),
      ]).single;

      final saved = agentRunPayloadWithCorrection(run, '  bad change  ');
      expect(saved['existing'], {'nested': true});
      expect(saved['value'], 7);
      expect(saved['correction'], {
        'note': 'bad change',
        'incorrect': true,
        'resolved': false,
      });

      final cleared = agentRunPayloadWithoutCorrection(
        buildAgentRuns([
          _agentRow(
            id: '2',
            event: 'agent_run_end',
            seconds: 2,
            payload: saved,
          ),
        ]).single,
      );
      expect(cleared['existing'], {'nested': true});
      expect(cleared['value'], 7);
      expect(cleared.containsKey('correction'), isFalse);
    });
  });
}

NexusLogRow _agentRow({
  required String id,
  required String event,
  required int seconds,
  Map<String, dynamic> payload = const {},
}) {
  return NexusLogRow(
    id: id,
    time: DateTime.utc(2026, 7, 3, 12, 0, seconds),
    receivedAt: DateTime.utc(2026, 7, 3, 12, 0, seconds),
    originKind: 'app',
    origin: 'nx_main',
    severity: 'INFO',
    message: '',
    userId: 'user-1',
    deviceId: '',
    sessionId: 'session-1',
    traceId: 'run-1',
    eventName: event,
    category: 'agent',
    payload: {
      'agent_run_id': 'run-1',
      'event_name': event,
      ...payload,
    },
  );
}
