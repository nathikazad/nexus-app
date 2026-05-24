import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_voice_assistant/features/logs/log_pipeline_mappers.dart';
import 'package:nexus_voice_assistant/features/logs/log_pipeline_models.dart';
import 'package:nexus_voice_assistant/features/logs/logs_providers.dart';
import 'package:nx_db/nx_db.dart';

class AudioLogDetailPage extends ConsumerWidget {
  const AudioLogDetailPage({
    super.key,
    required this.date,
    required this.turnkey,
  });

  final DateTime date;
  final String turnkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPipelineTurnsProvider(date));
    return _DetailScaffold(
      title: 'Audio Pipeline',
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorText(error: error),
        data: (turns) {
          final turn =
              turns.where((item) => item.turnkey == turnkey).firstOrNull;
          if (turn == null) return const Center(child: Text('Turn not found.'));
          return _AudioTurnDetail(date: date, turn: turn);
        },
      ),
    );
  }
}

class AgentLogDetailPage extends ConsumerWidget {
  const AgentLogDetailPage({
    super.key,
    required this.date,
    required this.runId,
  });

  final DateTime date;
  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agentPipelineRunsProvider(date));
    return _DetailScaffold(
      title: 'Agent Pipeline',
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorText(error: error),
        data: (runs) {
          final run = runs.where((item) => item.runId == runId).firstOrNull;
          if (run == null)
            return const Center(child: Text('Agent run not found.'));
          return _AgentRunDetail(date: date, run: run);
        },
      ),
    );
  }
}

class DbChangeDetailPage extends ConsumerWidget {
  const DbChangeDetailPage({
    super.key,
    required this.date,
    required this.operationId,
  });

  final DateTime date;
  final String operationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      dbChangeDetailProvider(
          DbChangeDetailKey(date: date, operationId: operationId)),
    );
    return _DetailScaffold(
      title: 'DB Changes',
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorText(error: error),
        data: (detail) => _DbChangeDetailView(detail: detail),
      ),
    );
  }
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LogDetailUi.gray50,
      appBar: AppBar(
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _LogDetailUi.gray950,
                fontWeight: FontWeight.w700,
              ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _LogDetailUi.gray200),
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}

class _AudioTurnDetail extends ConsumerWidget {
  const _AudioTurnDetail({required this.date, required this.turn});

  final DateTime date;
  final AudioPipelineTurn turn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentRuns = ref.watch(agentPipelineRunsProvider(date)).maybeWhen(
        data: (runs) => runs, orElse: () => const <AgentPipelineRun>[]);
    final relatedLinks = _audioTurnRelatedLinks(turn, date, agentRuns);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(
          title: 'Turn ${turn.turnkey}',
          status: turn.status,
          subtitle:
              '${turn.logs.length} rows / ${_formatDuration(turn.durationMs)}',
        ),
        if (relatedLinks.isNotEmpty)
          _Section(
            title: 'Related',
            child: _RelatedLinks(links: relatedLinks),
          ),
        _Section(
          title: 'Pipeline',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final stage in turn.stages) _StageBox(stage: stage),
            ],
          ),
        ),
        _TextSection(title: 'User Transcript', text: turn.transcript),
        _TextSection(title: 'Agent Response', text: turn.assistant),
        _Section(
          title: 'Audio Summary',
          child: Column(
            children: [
              for (final entry in turn.summaries.entries)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key),
                  trailing: Text(
                    '${entry.value.packets ?? '-'} packets / ${entry.value.bytes ?? '-'} bytes',
                  ),
                ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('ESP32 playback'),
                trailing:
                    Text('${turn.decoded} decoded / ${turn.played} played'),
              ),
            ],
          ),
        ),
        _RowsSection(
          rows: turn.logs,
          linksForRow: (row) => _audioRowLinks(row, date, agentRuns),
        ),
      ],
    );
  }
}

class _AgentRunDetail extends StatelessWidget {
  const _AgentRunDetail({required this.date, required this.run});

  final DateTime date;
  final AgentPipelineRun run;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(
          title: run.runId,
          status: run.status,
          subtitle:
              '${run.agentName.isEmpty ? run.agentId : run.agentName} / ${run.logs.length} rows / ${_formatDuration(run.durationMs)}',
        ),
        _TextSection(title: 'User Statement', text: run.userText),
        _TextSection(title: 'Final Response', text: run.response),
        _Section(
          title: 'Run Summary',
          child: Column(
            children: [
              _KeyValue('client_app', run.clientApp),
              _KeyValue('session_id', run.sessionId),
              _KeyValue('order_id', run.orderId),
              _KeyValue('tool_calls', run.toolCalls.toString()),
              _KeyValue('tool_errors', run.toolErrors.toString()),
              _KeyValue('db_changes', run.changeOperationIds.join(', ')),
              _KeyValue('tokens', run.tokenUsage.totalTokens.toString()),
            ],
          ),
        ),
        _RowsSection(
          rows: run.logs,
          linksForRow: (row) => _agentRowLinks(row, date),
        ),
      ],
    );
  }
}

class _DbChangeDetailView extends StatelessWidget {
  const _DbChangeDetailView({required this.detail});

  final DbChangeDetail detail;

  @override
  Widget build(BuildContext context) {
    final title =
        dbOperationTitle(detail.operation, detail.events, detail.metadata);
    final affectedModels = _affectedModelRefs(detail.events, detail.metadata);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(
          title: title,
          status: detail.operation.reversalOfOperationId.isNotEmpty
              ? 'reversal'
              : detail.operation.reversedByOperationId.isNotEmpty
                  ? 'reversed'
                  : 'active',
          subtitle:
              '${detail.events.length} row changes / ${detail.operation.id}',
        ),
        _Section(
          title: 'Source',
          child: Column(
            children: [
              _KeyValue('source_kind', detail.operation.sourceKind),
              _KeyValue('source_id', detail.operation.sourceId),
              _KeyValue('source_label', detail.operation.sourceLabel),
              _KeyValue('user_id', detail.operation.userId),
              _KeyValue('domain_id', detail.operation.domainId),
              _KeyValue('txid', detail.operation.txid),
            ],
          ),
        ),
        if (affectedModels.isNotEmpty)
          _Section(
            title: 'Affected Models',
            child: _AffectedModelsPanel(models: affectedModels),
          ),
        _Section(
          title: 'Row Changes',
          child: Column(
            children: [
              for (final event in detail.events)
                _DbEventTile(
                  event: event,
                  events: detail.events,
                  metadata: detail.metadata,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DbEventTile extends StatelessWidget {
  const _DbEventTile({
    required this.event,
    required this.events,
    required this.metadata,
  });

  final DbChangeEvent event;
  final List<DbChangeEvent> events;
  final DbChangeMetadata metadata;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _panelDecoration(),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        title: Text(
          describeDbChangeEvent(event, events, metadata),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: _LogDetailUi.gray950,
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${event.op} ${event.tableName} #${event.id}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _LogDetailUi.gray500,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _JsonBlock(title: 'Primary key', value: event.rowPk),
          _JsonBlock(title: 'Before', value: event.beforeRow),
          _JsonBlock(title: 'After', value: event.afterRow),
        ],
      ),
    );
  }
}

class _AffectedModelsPanel extends StatelessWidget {
  const _AffectedModelsPanel({required this.models});

  final List<_AffectedModelRef> models;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final model in models)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.push('/model-detail/${model.modelId}'),
              child: Ink(
                decoration: BoxDecoration(
                  color: _LogDetailUi.blue.withValues(alpha: 0.08),
                  border: Border.all(
                    color: _LogDetailUi.blue.withValues(alpha: 0.24),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _LogDetailUi.blue.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.data_object_rounded,
                          color: _LogDetailUi.blue,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${model.modelTypeName} #${model.modelId}',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: _LogDetailUi.gray950,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(width: 7),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: _LogDetailUi.blue,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AffectedModelRef {
  const _AffectedModelRef({
    required this.modelId,
    required this.modelTypeName,
  });

  final int modelId;
  final String modelTypeName;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.status,
    required this.subtitle,
  });

  final String title;
  final String status;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: DecoratedBox(
        decoration: _panelDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _LogDetailUi.gray950,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                    ),
                  ),
                  _StatusPill(status: status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _LogDetailUi.gray500,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 8),
              child: Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _LogDetailUi.gray500,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
              ),
            ),
            DecoratedBox(
              decoration: _panelDecoration(),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      child: Text(
        text.isEmpty ? 'Not logged.' : text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _LogDetailUi.gray700,
              height: 1.45,
            ),
      ),
    );
  }
}

class _StageBox extends StatelessWidget {
  const _StageBox({required this.stage});

  final PipelineStage stage;

  @override
  Widget build(BuildContext context) {
    final color = switch (stage.state) {
      'done' => Colors.green.shade700,
      'error' => Colors.red.shade700,
      _ => Colors.grey.shade500,
    };
    return Container(
      width: 102,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.20)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(height: 7),
          Text(
            stage.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _LogDetailUi.gray700,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            stage.time == null ? '-' : _formatTime(stage.time!),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _LogDetailUi.gray500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _RowsSection extends StatelessWidget {
  const _RowsSection({required this.rows, this.linksForRow});

  final List<NexusLogRow> rows;
  final List<_LogRowLink> Function(NexusLogRow row)? linksForRow;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Raw Rows',
      child: Column(
        children: [
          for (final row in rows)
            _RawRowTile(row: row, links: linksForRow?.call(row) ?? const []),
        ],
      ),
    );
  }
}

class _RawRowTile extends StatelessWidget {
  const _RawRowTile({required this.row, required this.links});

  final NexusLogRow row;
  final List<_LogRowLink> links;

  @override
  Widget build(BuildContext context) {
    final name = eventName(row).isEmpty ? row.category : eventName(row);
    final normalized = normalizedPayload(row);
    // Temporarily hidden to keep the row expansion focused on event payloads.
    // final detail = <String, dynamic>{
    //   'time': row.time?.toIso8601String(),
    //   'receivedAt': row.receivedAt?.toIso8601String(),
    //   'originKind': row.originKind,
    //   'origin': row.origin,
    //   'severity': row.severity,
    //   'message': row.message,
    //   'userId': row.userId,
    //   'deviceId': row.deviceId,
    //   'sessionId': row.sessionId,
    //   'traceId': row.traceId,
    //   'eventName': row.eventName,
    //   'category': row.category,
    //   'payload': row.payload,
    // };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _LogDetailUi.gray200),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _LogDetailUi.gray200),
        ),
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name.isEmpty ? 'log row' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: _LogDetailUi.gray950,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              row.time == null ? '' : _formatTime(row.time!),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: _LogDetailUi.gray500,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            row.message.isEmpty ? _bestPayloadPreview(normalized) : row.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _LogDetailUi.gray600,
                  height: 1.35,
                ),
          ),
        ),
        children: [
          if (links.isNotEmpty) _RelatedLinks(links: links),
          if (row.message.isNotEmpty)
            _JsonBlock(title: 'Message', value: {'text': row.message}),
          if (normalized.isNotEmpty)
            _JsonBlock(title: 'Normalized payload', value: normalized),
          // _JsonBlock(title: 'Full row', value: detail),
        ],
      ),
    );
  }
}

class _RelatedLinks extends StatelessWidget {
  const _RelatedLinks({required this.links});

  final List<_LogRowLink> links;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final link in links) _RelatedLinkChip(link: link),
      ],
    );
  }
}

class _RelatedLinkChip extends StatelessWidget {
  const _RelatedLinkChip({required this.link});

  final _LogRowLink link;

  @override
  Widget build(BuildContext context) {
    final color = _relatedLinkColor(link);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push(link.route),
        child: Ink(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.24)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(_relatedLinkIcon(link), color: color, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  link.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: _LogDetailUi.gray950,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(width: 7),
                Icon(
                  Icons.chevron_right_rounded,
                  color: color,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogRowLink {
  const _LogRowLink({required this.label, required this.route});

  final String label;
  final String route;
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.name, this.value);

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              name,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _LogDetailUi.gray500,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _LogDetailUi.gray700,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JsonBlock extends StatelessWidget {
  const _JsonBlock({required this.title, required this.value});

  final String title;
  final Object value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          DecoratedBox(
            decoration: BoxDecoration(
              color: _LogDetailUi.gray50,
              border: Border.all(color: _LogDetailUi.gray200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  const JsonEncoder.withIndent('  ').convert(value),
                  style: const TextStyle(
                    color: _LogDetailUi.gray700,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.35,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          status.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    border: Border.all(color: _LogDetailUi.gray200),
    borderRadius: BorderRadius.circular(8),
    boxShadow: const [
      BoxShadow(
        color: Color(0x06000000),
        blurRadius: 10,
        offset: Offset(0, 3),
      ),
    ],
  );
}

Color _statusColor(String status) {
  switch (status) {
    case 'complete':
    case 'active':
      return const Color(0xFF15803D);
    case 'failed':
      return const Color(0xFFB91C1C);
    case 'partial':
    case 'reversed':
    case 'reversal':
      return const Color(0xFFC2410C);
    case 'incomplete':
      return const Color(0xFF1D4ED8);
    default:
      return _LogDetailUi.gray600;
  }
}

Color _relatedLinkColor(_LogRowLink link) {
  if (link.route.startsWith('/logs/db/')) return _LogDetailUi.orange;
  if (link.label.toLowerCase().contains('kgql')) return _LogDetailUi.violet;
  return _LogDetailUi.blue;
}

IconData _relatedLinkIcon(_LogRowLink link) {
  if (link.route.startsWith('/logs/db/')) return Icons.storage_rounded;
  if (link.label.toLowerCase().contains('kgql')) {
    return Icons.account_tree_rounded;
  }
  return Icons.graphic_eq_rounded;
}

abstract final class _LogDetailUi {
  static const gray50 = Color(0xFFF9FAFB);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray500 = Color(0xFF6B7280);
  static const gray600 = Color(0xFF4B5563);
  static const gray700 = Color(0xFF374151);
  static const gray950 = Color(0xFF030712);
  static const blue = Color(0xFF2563EB);
  static const violet = Color(0xFF7C3AED);
  static const orange = Color(0xFFEA580C);
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Failed to load detail:\n$error',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String _formatDuration(int ms) {
  if (ms <= 0) return '-';
  if (ms < 1000) return '${ms}ms';
  final seconds = ms / 1000;
  return seconds < 10
      ? '${seconds.toStringAsFixed(1)}s'
      : '${seconds.round()}s';
}

List<_LogRowLink> _audioRowLinks(
  NexusLogRow row,
  DateTime date,
  List<AgentPipelineRun> runs,
) {
  if (eventName(row) != 'llm_response') return const [];
  final payload = normalizedPayload(row);
  final orderId = (payload['order_id'] ?? '').toString();
  final sessionId = (payload['session_id'] ?? row.sessionId).toString();
  final run = runs.where((candidate) {
    if (orderId.isNotEmpty && candidate.orderId == orderId) return true;
    return sessionId.isNotEmpty && candidate.sessionId == sessionId;
  }).firstOrNull;
  if (run == null) return const [];
  return [
    _LogRowLink(
      label: 'Open agent run',
      route:
          '/logs/agent/${Uri.encodeComponent(run.runId)}?date=${formatLogDate(date)}',
    ),
  ];
}

List<_LogRowLink> _audioTurnRelatedLinks(
  AudioPipelineTurn turn,
  DateTime date,
  List<AgentPipelineRun> runs,
) {
  final links = <_LogRowLink>[];
  final seenRoutes = <String>{};

  void addLink(_LogRowLink link) {
    if (seenRoutes.add(link.route)) links.add(link);
  }

  final audioAgentRunIds = <String>{};
  for (final row in turn.logs) {
    for (final link in _audioRowLinks(row, date, runs)) {
      addLink(
        _LogRowLink(
          label: 'Open audio agent run',
          route: link.route,
        ),
      );
      final runId = _agentRunIdFromRoute(link.route);
      if (runId.isNotEmpty) audioAgentRunIds.add(runId);
    }
  }

  final kgqlRunIds = <String>{};
  for (final runId in audioAgentRunIds) {
    final run = runs.where((candidate) => candidate.runId == runId).firstOrNull;
    if (run == null) continue;
    for (final row in run.logs) {
      for (final link in _agentRowLinks(row, date)) {
        addLink(link);
        final linkedRunId = _agentRunIdFromRoute(link.route);
        if (linkedRunId.isNotEmpty) kgqlRunIds.add(linkedRunId);
      }
    }
  }

  for (final runId in kgqlRunIds) {
    final run = runs.where((candidate) => candidate.runId == runId).firstOrNull;
    if (run == null) continue;
    for (final row in run.logs) {
      for (final link in _agentRowLinks(row, date)) {
        addLink(link);
      }
    }
  }

  return links;
}

List<_LogRowLink> _agentRowLinks(NexusLogRow row, DateTime date) {
  final payload = normalizedPayload(row);
  final toolName = (payload['tool_name'] ?? '').toString();
  final result = payload['result'];
  final resultMap = result is Map ? Map<String, dynamic>.from(result) : null;
  final links = <_LogRowLink>[];

  if (toolName == 'ask_kgql_agent' && resultMap != null) {
    final kgqlRunId = (resultMap['kgql_agent_run_id'] ?? '').toString();
    if (kgqlRunId.isNotEmpty) {
      links.add(
        _LogRowLink(
          label: 'Open KGQL agent run',
          route:
              '/logs/agent/${Uri.encodeComponent(kgqlRunId)}?date=${formatLogDate(date)}',
        ),
      );
    }
    for (final operationId
        in _stringList(resultMap['kgql_change_operation_ids'])) {
      links.add(
        _LogRowLink(
          label: 'Open DB change ${_shortId(operationId)}',
          route:
              '/logs/db/${Uri.encodeComponent(operationId)}?date=${formatLogDate(date)}',
        ),
      );
    }
  }

  final operationId = (payload['change_operation_id'] ?? '').toString();
  if (_isKgqlMutationTool(toolName) && operationId.isNotEmpty) {
    links.add(
      _LogRowLink(
        label: 'Open DB change ${_shortId(operationId)}',
        route:
            '/logs/db/${Uri.encodeComponent(operationId)}?date=${formatLogDate(date)}',
      ),
    );
  }

  return links;
}

String _agentRunIdFromRoute(String route) {
  const prefix = '/logs/agent/';
  if (!route.startsWith(prefix)) return '';
  final end = route.indexOf('?');
  final encoded = end == -1
      ? route.substring(prefix.length)
      : route.substring(prefix.length, end);
  return Uri.decodeComponent(encoded);
}

List<_AffectedModelRef> _affectedModelRefs(
  List<DbChangeEvent> events,
  DbChangeMetadata metadata,
) {
  final refs = <int, _AffectedModelRef>{};

  void add(Object? modelId, Object? modelTypeId) {
    final id = int.tryParse(modelId?.toString() ?? '');
    if (id == null || refs.containsKey(id)) return;
    refs[id] = _AffectedModelRef(
      modelId: id,
      modelTypeName: metadata.modelTypeName(modelTypeId),
    );
  }

  for (final event in events) {
    final row = event.op == 'delete' ? event.beforeRow : event.afterRow;
    final before = event.beforeRow;
    final after = event.afterRow;
    switch (event.tableName) {
      case 'models':
        add(row['id'] ?? event.rowPk['id'], row['model_type_id']);
      case 'attributes':
        add(row['model_id'], _modelTypeIdForModelId(row['model_id'], events));
      case 'relations':
        final relationship = metadata.relationshipTypes[
            int.tryParse(row['relationship_type_id']?.toString() ?? '')];
        add(
            row['from_id'] ?? before['from_id'] ?? after['from_id'],
            relationship?['fromModelTypeId'] ??
                relationship?['from_model_type_id']);
        add(
            row['to_id'] ?? before['to_id'] ?? after['to_id'],
            relationship?['toModelTypeId'] ??
                relationship?['to_model_type_id']);
      case 'relation_attributes':
        final relationId = row['relation_id'];
        for (final relationEvent in events) {
          if (relationEvent.tableName != 'relations') continue;
          final relationRow = relationEvent.afterRow.isNotEmpty
              ? relationEvent.afterRow
              : relationEvent.beforeRow;
          if (relationRow['id']?.toString() != relationId?.toString()) {
            continue;
          }
          final relationship = metadata.relationshipTypes[int.tryParse(
              relationRow['relationship_type_id']?.toString() ?? '')];
          add(
              relationRow['from_id'],
              relationship?['fromModelTypeId'] ??
                  relationship?['from_model_type_id']);
          add(
              relationRow['to_id'],
              relationship?['toModelTypeId'] ??
                  relationship?['to_model_type_id']);
        }
    }
  }

  return refs.values.toList()
    ..sort((a, b) {
      final type = a.modelTypeName.compareTo(b.modelTypeName);
      if (type != 0) return type;
      return a.modelId.compareTo(b.modelId);
    });
}

Object? _modelTypeIdForModelId(Object? modelId, List<DbChangeEvent> events) {
  final id = int.tryParse(modelId?.toString() ?? '');
  if (id == null) return null;
  for (final event in events) {
    if (event.tableName != 'models') continue;
    final row = event.afterRow.isNotEmpty ? event.afterRow : event.beforeRow;
    if (int.tryParse(row['id']?.toString() ?? '') == id) {
      return row['model_type_id'];
    }
  }
  return null;
}

bool _isKgqlMutationTool(String toolName) {
  return toolName == 'set_kgql_models' || toolName == 'set_kgql_model_types';
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return [
      for (final item in value)
        if (item != null && item.toString().isNotEmpty) item.toString(),
    ];
  }
  return const [];
}

String _shortId(String value) {
  return value.length <= 8 ? value : value.substring(0, 8);
}

String _bestPayloadPreview(Map<String, dynamic> payload) {
  for (final key in [
    'user_text',
    'response',
    'prompt',
    'text',
    'transcript',
    'result',
  ]) {
    final value = payload[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  }
  return payload.isEmpty ? '' : jsonEncode(payload);
}
