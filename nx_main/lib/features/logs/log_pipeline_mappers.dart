import 'package:nexus_voice_assistant/features/logs/log_pipeline_models.dart';
import 'package:nx_db/nx_db.dart';

const _necklacePipelineStages = [
  _StageDef('mic', 'Mic', [
    'mic_button_held',
    'mic_button_released',
    'clock_anchored',
    'mic_record_start'
  ]),
  _StageDef('esp32_up', 'ESP32 -> nRF', ['opus_packets_sent']),
  _StageDef('nrf_up', 'nRF -> App',
      ['esp32_opus_received_summary', 'nx_opus_sent_summary']),
  _StageDef('app_up', 'App -> MCP', ['nrf_opus_reception_summary']),
  _StageDef(
      'server_in', 'MCP In', ['audio_received_summary', 'audio_input_summary']),
  _StageDef('stt', 'STT', ['stt_transcript']),
  _StageDef('llm', 'LLM', ['llm_response']),
  _StageDef('server_out', 'MCP Out', ['audio_output_summary']),
  _StageDef('app_down', 'App <- MCP', ['websocket_opus_reception_summary']),
  _StageDef('nrf_down', 'nRF -> ESP32',
      ['nx_opus_received_summary', 'esp32_opus_sent_summary']),
  _StageDef('playback', 'Playback', [
    'speaker_play_start',
    'opus_decode_done',
    'pcm_packet_played',
    'speaker_play_stop'
  ]),
  _StageDef('sleep', 'Sleep', ['sleep_enter_start']),
];

const _appMcpPipelineStages = [
  _StageDef('app_up', 'App -> MCP', [
    'nrf_opus_reception_summary',
    'websocket_opus_sent_summary',
    'socket_audio_sent_summary'
  ]),
  _StageDef(
      'server_in', 'MCP In', ['audio_received_summary', 'audio_input_summary']),
  _StageDef('stt', 'STT', ['stt_transcript']),
  _StageDef('llm', 'LLM', ['llm_response']),
  _StageDef('server_out', 'MCP Out', ['audio_output_summary']),
  _StageDef('app_down', 'App <- MCP',
      ['websocket_opus_reception_summary', 'socket_audio_received_summary']),
];

const _lifecycleEvents = {
  'awoken',
  'clock_anchored',
  'mic_record_start',
  'mic_record_stop',
  'speaker_play_start',
  'speaker_play_stop',
  'sleep_enter_start',
};

const _utilityEvents = {
  'awoken',
  'clock_anchored',
  'sleep_requested',
  'sleep_enter_start',
  'sleep_hold',
  'sleep_release',
};

List<AudioPipelineTurn> buildAudioPipelineTurns(List<NexusLogRow> rows) {
  final sorted = [...rows]..sort(_compareRows);
  final groups = <String, List<NexusLogRow>>{};
  final lifecycleRows = <NexusLogRow>[];

  for (final row in sorted) {
    final key = turnkeyFor(row);
    if (key.isEmpty) continue;
    if (_utilityEvents.contains(eventName(row))) {
      lifecycleRows.add(row);
      continue;
    }
    groups.putIfAbsent(key, () => []).add(row);
  }

  final boundsByKey = {
    for (final entry in groups.entries) entry.key: _groupBounds(entry.value),
  };
  for (final row in lifecycleRows) {
    final ms = _rowMs(row);
    var bestKey = '';
    var bestDistance = 1 << 62;
    for (final entry in boundsByKey.entries) {
      final distance = _distanceToBounds(ms, entry.value);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestKey = entry.key;
      }
    }
    if (bestKey.isNotEmpty && bestDistance <= 10000) {
      groups[bestKey]?.add(row);
      boundsByKey[bestKey] = _groupBounds(groups[bestKey] ?? const []);
    }
  }

  return groups.entries
      .map((entry) => _analyzeTurn(entry.key, entry.value))
      .where((turn) => turn.logs.any((row) => isAudioEventName(eventName(row))))
      .toList()
    ..sort((a, b) => b.lastMs.compareTo(a.lastMs));
}

List<AgentPipelineRun> buildAgentRuns(List<NexusLogRow> rows) {
  final groups = <String, List<NexusLogRow>>{};
  for (final row in rows) {
    if (!isAgentEvent(row)) continue;
    final runId = agentRunIdFor(row);
    if (runId.isEmpty) continue;
    groups.putIfAbsent(runId, () => []).add(row);
  }
  return groups.entries
      .map((entry) => _analyzeAgentRun(entry.key, entry.value))
      .toList()
    ..sort((a, b) => b.lastMs.compareTo(a.lastMs));
}

String eventName(NexusLogRow row) {
  final payload = normalizedPayload(row);
  return (row.eventName.isNotEmpty
          ? row.eventName
          : payload['event_name'] ?? payload['type'] ?? row.category)
      .toString()
      .trim();
}

Map<String, dynamic> normalizedPayload(NexusLogRow row) {
  final payload = row.payload;
  final raw = payload['raw'];
  if (raw is Map) {
    return {...payload, ...Map<String, dynamic>.from(raw)};
  }
  return payload;
}

String turnkeyFor(NexusLogRow row) {
  final payload = normalizedPayload(row);
  final turnkey = payload['turnkey'] ?? payload['turn_key'];
  if (turnkey != null && turnkey.toString().isNotEmpty)
    return turnkey.toString();
  final nonce = payload['nonce'];
  final turnId = payload['turn_id'] ?? payload['turn'];
  if (nonce != null &&
      nonce.toString().isNotEmpty &&
      turnId != null &&
      turnId.toString().isNotEmpty) {
    return '$nonce:$turnId';
  }
  return '';
}

bool isAgentEvent(NexusLogRow row) {
  final payload = normalizedPayload(row);
  return row.category == 'agent' ||
      payload['agent_run_id'] != null ||
      eventName(row).startsWith('agent_');
}

String agentRunIdFor(NexusLogRow row) {
  final payload = normalizedPayload(row);
  return (payload['agent_run_id'] ?? row.traceId).toString();
}

String dbOperationTitle(
  DbChangeOperation operation,
  List<DbChangeEvent> events,
  DbChangeMetadata? metadata,
) {
  if (events.isNotEmpty)
    return describeDbChangeEvent(events.first, events, metadata);
  if (operation.sourceLabel.isNotEmpty) return operation.sourceLabel;
  if (operation.sourceId.isNotEmpty) return operation.sourceId;
  return operation.id;
}

String dbOperationSummary(List<DbChangeEvent>? events) {
  if (events == null) return 'open for row changes';
  if (events.isEmpty) return '0 row changes';
  final counts = <String, int>{};
  for (final event in events) {
    final key = '${event.op} ${event.tableName}';
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts.entries
      .map((entry) => '${entry.value} ${entry.key}')
      .join(', ');
}

String describeDbChangeEvent(
  DbChangeEvent event,
  List<DbChangeEvent> operationEvents,
  DbChangeMetadata? metadata,
) {
  final row = event.op == 'delete' ? event.beforeRow : event.afterRow;
  final verb = event.op == 'insert'
      ? 'created'
      : event.op == 'update'
          ? 'updated'
          : 'deleted';
  if (event.tableName == 'models') {
    final typeName = metadata?.modelTypeName(row['model_type_id']) ??
        'model_type ${row['model_type_id'] ?? '-'}';
    final name = row['name'] == null ? '' : ' "${row['name']}"';
    return 'Model$name with id:${row['id'] ?? _rowPkId(event)} of type $typeName $verb.';
  }
  if (event.tableName == 'attributes') {
    final modelId = row['model_id'] ?? '-';
    final key = metadata?.attributeKey(row['attribute_definition_id']) ??
        'attribute ${row['attribute_definition_id'] ?? '-'}';
    return 'Model $modelId $verb $key.';
  }
  return '${_capitalize(event.tableName.isEmpty ? 'row' : event.tableName)} row ${_rowPkId(event).isEmpty ? '' : 'with id:${_rowPkId(event)} '}$verb.';
}

bool isAudioEventName(String name) {
  if (name.isEmpty || _utilityEvents.contains(name)) return false;
  return [
        ..._necklacePipelineStages,
        ..._appMcpPipelineStages
      ].any((stage) => stage.id != 'camera' && stage.events.contains(name)) ||
      name.startsWith('audio_') ||
      name.startsWith('opus_') ||
      name.startsWith('pcm_') ||
      name.startsWith('speaker_') ||
      name.startsWith('mic_') ||
      name.startsWith('turn_') ||
      name == 'stt_transcript' ||
      name == 'llm_response';
}

AudioPipelineTurn _analyzeTurn(String turnkey, List<NexusLogRow> logs) {
  final sorted = [...logs]..sort(_compareRows);
  final events = <String, NexusLogRow>{};
  final origins = <String>{};
  final summaries = <String, PipelineSummary>{};
  final lifecycle = <NexusLogRow>[];
  var transcript = '';
  var assistant = '';
  var hasError = false;
  var hasWarn = false;
  var decoded = 0;
  var played = 0;
  var agentId = '';
  var agentName = '';
  var clientApp = '';

  for (final row in sorted) {
    final payload = normalizedPayload(row);
    final event = eventName(row);
    final identity = _agentIdentityForRow(row);
    agentId = agentId.isEmpty ? identity.agentId : agentId;
    agentName = agentName.isEmpty ? identity.agentName : agentName;
    clientApp = clientApp.isEmpty ? identity.clientApp : clientApp;
    if (event.isNotEmpty) events.putIfAbsent(event, () => row);
    if (row.origin.isNotEmpty) origins.add(row.origin);
    final severity = row.severity.toUpperCase();
    hasError = hasError ||
        {'ERROR', 'ERR', 'FATAL'}.contains(severity) ||
        RegExp('fail|timeout', caseSensitive: false)
            .hasMatch('$event ${row.message}');
    hasWarn = hasWarn || {'WARN', 'WARNING'}.contains(severity);
    if (event == 'stt_transcript') {
      transcript =
          (payload['transcript'] ?? payload['text'] ?? row.message).toString();
    }
    if (event == 'llm_response') {
      assistant =
          (payload['response'] ?? payload['text'] ?? row.message).toString();
    }
    if (event == 'opus_decode_done') decoded += 1;
    if (event == 'pcm_packet_played') played += 1;
    if (_lifecycleEvents.contains(event)) lifecycle.add(row);
    if (event.endsWith('_summary') ||
        event == 'opus_packets_sent' ||
        event == 'audio_received_summary' ||
        event == 'audio_output_summary') {
      summaries[event] = PipelineSummary(
        packets: _packetCount(payload),
        bytes: _byteCount(payload),
        row: row,
      );
    }
  }

  final stageDefs = _isNecklaceAgent(agentId)
      ? _necklacePipelineStages
      : _appMcpPipelineStages;
  final stages = stageDefs.map((stage) {
    final rows =
        sorted.where((row) => stage.events.contains(eventName(row))).toList();
    final severe = rows.any((row) =>
        {'ERROR', 'ERR', 'FATAL'}.contains(row.severity.toUpperCase()));
    return PipelineStage(
      id: stage.id,
      label: stage.label,
      events: stage.events,
      rows: rows,
      state: severe
          ? 'error'
          : rows.isNotEmpty
              ? 'done'
              : 'missing',
      time: rows.isEmpty ? null : rows.first.time,
    );
  }).toList();

  final firstMs = _rowMs(sorted.firstOrNull);
  final lastMs = _rowMs(sorted.lastOrNull);
  final complete = events.containsKey('speaker_play_stop') ||
      events.containsKey('sleep_enter_start');
  final criticalStageIds = _isNecklaceAgent(agentId)
      ? const ['stt', 'llm', 'server_out', 'playback']
      : const ['server_in', 'stt', 'llm', 'server_out'];
  final missingCritical = stages
      .where((stage) =>
          stage.state == 'missing' && criticalStageIds.contains(stage.id))
      .toList();
  final packetMismatch = decoded > 0 && played > 0 && decoded != played;
  final status = hasError
      ? 'failed'
      : complete && missingCritical.isEmpty && !packetMismatch
          ? 'complete'
          : packetMismatch || hasWarn || missingCritical.isNotEmpty
              ? 'partial'
              : 'active';

  return AudioPipelineTurn(
    turnkey: turnkey,
    logs: sorted,
    origins: origins.toList(),
    agentId: agentId,
    agentName: agentName,
    clientApp: clientApp,
    stages: stages,
    status: status,
    transcript: transcript,
    assistant: assistant,
    summaries: summaries,
    decoded: decoded,
    played: played,
    lifecycle: lifecycle,
    firstMs: firstMs,
    lastMs: lastMs,
    durationMs: (lastMs - firstMs).clamp(0, 1 << 62),
    missingCritical: missingCritical,
    packetMismatch: packetMismatch,
  );
}

AgentPipelineRun _analyzeAgentRun(String runId, List<NexusLogRow> logs) {
  final sorted = [...logs]..sort(_compareRows);
  var userText = '';
  var response = '';
  var status = 'incomplete';
  var hasRunEnd = false;
  var toolCalls = 0;
  var toolErrors = 0;
  var agentId = '';
  var agentName = '';
  var clientApp = '';
  var sessionId = '';
  var orderId = '';
  var tokenUsage =
      const TokenUsage(inputTokens: 0, outputTokens: 0, totalTokens: 0);
  final changeOperationIds = <String>{};

  for (final row in sorted) {
    final payload = normalizedPayload(row);
    final event = eventName(row);
    agentId =
        agentId.isEmpty ? (payload['agent_id'] ?? '').toString() : agentId;
    agentName = agentName.isEmpty
        ? (payload['agent_name'] ?? '').toString()
        : agentName;
    clientApp = clientApp.isEmpty
        ? (payload['client_app'] ?? '').toString()
        : clientApp;
    sessionId = sessionId.isEmpty
        ? (payload['session_id'] ?? row.sessionId).toString()
        : sessionId;
    orderId =
        orderId.isEmpty ? (payload['order_id'] ?? '').toString() : orderId;
    if (event == 'agent_run_start')
      userText = (payload['user_text'] ?? row.message).toString();
    if (event == 'agent_model_response')
      response = (payload['response'] ?? row.message).toString();
    if (event == 'agent_tool_call') toolCalls += 1;
    if (event == 'agent_tool_error') toolErrors += 1;
    if (payload['change_operation_id'] != null) {
      changeOperationIds.add(payload['change_operation_id'].toString());
    }
    if (event == 'agent_run_end') {
      hasRunEnd = true;
      final usage = payload['token_usage'];
      final usageMap = usage is Map
          ? Map<String, dynamic>.from(usage)
          : const <String, dynamic>{};
      final input =
          _intValue(usageMap['input_tokens'] ?? usageMap['inputTokens']);
      final output =
          _intValue(usageMap['output_tokens'] ?? usageMap['outputTokens']);
      var total =
          _intValue(usageMap['total_tokens'] ?? usageMap['totalTokens']);
      total = total == 0 ? input + output : total;
      tokenUsage = TokenUsage(
          inputTokens: input, outputTokens: output, totalTokens: total);
    }
    if (event == 'agent_run_error') status = 'failed';
  }
  if (status != 'failed') status = hasRunEnd ? 'complete' : 'incomplete';
  final firstMs = _rowMs(sorted.firstOrNull);
  final lastMs = _rowMs(sorted.lastOrNull);

  return AgentPipelineRun(
    runId: runId,
    logs: sorted,
    userText: userText,
    response: response,
    status: status,
    agentId: agentId,
    agentName: agentName,
    clientApp: clientApp,
    sessionId: sessionId,
    orderId: orderId,
    toolCalls: toolCalls,
    toolErrors: toolErrors,
    tokenUsage: tokenUsage,
    changeOperationIds: changeOperationIds.toList(),
    firstMs: firstMs,
    lastMs: lastMs,
    durationMs: (lastMs - firstMs).clamp(0, 1 << 62),
  );
}

_AgentIdentity _agentIdentityForRow(NexusLogRow row) {
  final payload = normalizedPayload(row);
  var agentId = (payload['agent_id'] ?? '').toString().trim();
  var agentName = (payload['agent_name'] ?? '').toString().trim();
  final clientApp = (payload['client_app'] ?? '').toString().trim();
  final origin = row.origin.trim();
  if (agentId.isEmpty && clientApp == 'nx_time') agentId = 'nx_time';
  if (agentId.isEmpty && (clientApp == 'nx_main' || clientApp == 'necklace')) {
    agentId = 'necklace';
  }
  if (agentId.isEmpty &&
      {'esp32', 'nrf53', 'nrf', 'necklace'}.contains(origin)) {
    agentId = 'necklace';
  }
  if (agentName.isEmpty && agentId == 'nx_time')
    agentName = 'Nx Time Assistant';
  if (agentName.isEmpty && agentId == 'necklace')
    agentName = 'Necklace Assistant';
  return _AgentIdentity(agentId, agentName, clientApp);
}

int _compareRows(NexusLogRow a, NexusLogRow b) {
  final time = _rowMs(a).compareTo(_rowMs(b));
  if (time != 0) return time;
  return a.id.compareTo(b.id);
}

int _rowMs(NexusLogRow? row) => row?.time?.millisecondsSinceEpoch ?? 0;

_Bounds _groupBounds(List<NexusLogRow> rows) {
  final times = rows.map(_rowMs).where((time) => time > 0).toList();
  if (times.isEmpty) return const _Bounds(0, 0);
  times.sort();
  return _Bounds(times.first, times.last);
}

int _distanceToBounds(int ms, _Bounds bounds) {
  if (ms == 0 || bounds.firstMs == 0) return 1 << 62;
  if (ms >= bounds.firstMs && ms <= bounds.lastMs) return 0;
  final first = (ms - bounds.firstMs).abs();
  final last = (ms - bounds.lastMs).abs();
  return first < last ? first : last;
}

int? _packetCount(Map<String, dynamic> payload) {
  return _nullableInt(payload['opus_packets'] ??
      payload['pcm_packets'] ??
      payload['packets'] ??
      payload['packet_count'] ??
      payload['count'] ??
      payload['pkt'] ??
      payload['packet_id']);
}

int? _byteCount(Map<String, dynamic> payload) {
  return _nullableInt(payload['bytes'] ??
      payload['total_size'] ??
      payload['size_bytes'] ??
      payload['size'] ??
      payload['opus_bytes']);
}

int? _nullableInt(Object? value) =>
    value == null ? null : int.tryParse(value.toString());

int _intValue(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;

bool _isNecklaceAgent(String agentId) =>
    agentId.isEmpty || agentId == 'necklace';

String _rowPkId(DbChangeEvent event) {
  return (event.rowPk['id'] ?? event.rowPk['ID'] ?? '').toString();
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

class _StageDef {
  const _StageDef(this.id, this.label, this.events);
  final String id;
  final String label;
  final List<String> events;
}

class _Bounds {
  const _Bounds(this.firstMs, this.lastMs);
  final int firstMs;
  final int lastMs;
}

class _AgentIdentity {
  const _AgentIdentity(this.agentId, this.agentName, this.clientApp);
  final String agentId;
  final String agentName;
  final String clientApp;
}
