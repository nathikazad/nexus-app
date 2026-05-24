import 'package:nx_db/nx_db.dart';

enum LogsViewMode {
  audioPipeline('Audio Pipeline'),
  agentPipeline('Agent Pipeline'),
  dbChanges('DB Changes');

  const LogsViewMode(this.label);
  final String label;
}

class PipelineStage {
  const PipelineStage({
    required this.id,
    required this.label,
    required this.events,
    required this.rows,
    required this.state,
    required this.time,
  });

  final String id;
  final String label;
  final List<String> events;
  final List<NexusLogRow> rows;
  final String state;
  final DateTime? time;
}

class AudioPipelineTurn {
  const AudioPipelineTurn({
    required this.turnkey,
    required this.logs,
    required this.origins,
    required this.agentId,
    required this.agentName,
    required this.clientApp,
    required this.stages,
    required this.status,
    required this.transcript,
    required this.assistant,
    required this.summaries,
    required this.decoded,
    required this.played,
    required this.lifecycle,
    required this.firstMs,
    required this.lastMs,
    required this.durationMs,
    required this.missingCritical,
    required this.packetMismatch,
  });

  final String turnkey;
  final List<NexusLogRow> logs;
  final List<String> origins;
  final String agentId;
  final String agentName;
  final String clientApp;
  final List<PipelineStage> stages;
  final String status;
  final String transcript;
  final String assistant;
  final Map<String, PipelineSummary> summaries;
  final int decoded;
  final int played;
  final List<NexusLogRow> lifecycle;
  final int firstMs;
  final int lastMs;
  final int durationMs;
  final List<PipelineStage> missingCritical;
  final bool packetMismatch;
}

class PipelineSummary {
  const PipelineSummary({
    required this.packets,
    required this.bytes,
    required this.row,
  });

  final int? packets;
  final int? bytes;
  final NexusLogRow row;
}

class AgentPipelineRun {
  const AgentPipelineRun({
    required this.runId,
    required this.logs,
    required this.userText,
    required this.response,
    required this.status,
    required this.agentId,
    required this.agentName,
    required this.clientApp,
    required this.sessionId,
    required this.orderId,
    required this.toolCalls,
    required this.toolErrors,
    required this.tokenUsage,
    required this.changeOperationIds,
    required this.firstMs,
    required this.lastMs,
    required this.durationMs,
  });

  final String runId;
  final List<NexusLogRow> logs;
  final String userText;
  final String response;
  final String status;
  final String agentId;
  final String agentName;
  final String clientApp;
  final String sessionId;
  final String orderId;
  final int toolCalls;
  final int toolErrors;
  final TokenUsage tokenUsage;
  final List<String> changeOperationIds;
  final int firstMs;
  final int lastMs;
  final int durationMs;
}

class TokenUsage {
  const TokenUsage({
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
  });

  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
}

class DbChangeDetail {
  const DbChangeDetail({
    required this.operation,
    required this.events,
    required this.metadata,
  });

  final DbChangeOperation operation;
  final List<DbChangeEvent> events;
  final DbChangeMetadata metadata;
}
