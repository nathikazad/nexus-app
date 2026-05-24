import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_voice_assistant/features/logs/log_pipeline_models.dart';
import 'package:nexus_voice_assistant/features/logs/logs_providers.dart';
import 'package:nx_db/nx_db.dart';

class LogViewerPage extends ConsumerWidget {
  const LogViewerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(logsViewModeProvider);
    final selectedDate = ref.watch(logsSelectedDateProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _LogsToolbar(mode: mode, selectedDate: selectedDate),
            Expanded(child: _LogsList(mode: mode, selectedDate: selectedDate)),
          ],
        ),
      ),
    );
  }
}

class _LogsToolbar extends ConsumerWidget {
  const _LogsToolbar({required this.mode, required this.selectedDate});

  final LogsViewMode mode;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final dbFilter = ref.watch(dbChangeFilterProvider);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _LogUi.gray200)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Logs',
                        style: textTheme.titleMedium?.copyWith(
                          color: _LogUi.gray950,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () =>
                              _selectDate(context, ref, selectedDate),
                          style: TextButton.styleFrom(
                            foregroundColor: _LogUi.gray700,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(formatLogDate(selectedDate)),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh logs',
                  onPressed: () =>
                      _refreshLogs(ref, mode, selectedDate, dbFilter),
                  icon: const Icon(Icons.refresh_rounded, size: 19),
                  style: IconButton.styleFrom(
                    foregroundColor: _LogUi.gray700,
                    backgroundColor: _LogUi.gray50,
                    side: const BorderSide(color: _LogUi.gray200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _LogsModeDropdown(mode: mode),
              ],
            ),
            if (mode == LogsViewMode.dbChanges) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _LogUi.gray50,
                  border: Border.all(color: _LogUi.gray200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: _DbChangeFilterDropdown(filter: dbFilter),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedDate,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      ref.read(logsSelectedDateProvider.notifier).setDate(picked);
    }
  }

  void _refreshLogs(
    WidgetRef ref,
    LogsViewMode mode,
    DateTime selectedDate,
    DbChangeFilter dbFilter,
  ) {
    switch (mode) {
      case LogsViewMode.audioPipeline:
        ref.invalidate(logsForDayProvider);
        ref.invalidate(audioPipelineTurnsProvider);
      case LogsViewMode.agentPipeline:
        ref.invalidate(logsForDayProvider);
        ref.invalidate(agentPipelineRunsProvider);
      case LogsViewMode.dbChanges:
        ref.invalidate(dbChangeOperationsProvider);
        ref.invalidate(dbChangeEventsProvider);
        ref.invalidate(dbChangeOperationsWithEventsProvider);
        ref.invalidate(dbChangeDetailProvider);
    }
  }
}

class _LogsModeDropdown extends ConsumerWidget {
  const _LogsModeDropdown({required this.mode});

  final LogsViewMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _LogUi.gray950,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButton<LogsViewMode>(
          value: mode,
          dropdownColor: Colors.white,
          iconEnabledColor: Colors.white,
          style: textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          underline: const SizedBox.shrink(),
          alignment: AlignmentDirectional.centerEnd,
          borderRadius: BorderRadius.circular(8),
          items: [
            for (final item in LogsViewMode.values)
              DropdownMenuItem(
                value: item,
                child: Text(
                  item.label,
                  style: textTheme.labelLarge?.copyWith(
                    color: _LogUi.gray950,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
          selectedItemBuilder: (context) => [
            for (final item in LogsViewMode.values)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item.label,
                  style: textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              ref.read(logsViewModeProvider.notifier).setMode(value);
            }
          },
        ),
      ),
    );
  }
}

class _DbChangeFilterDropdown extends ConsumerWidget {
  const _DbChangeFilterDropdown({required this.filter});

  final DbChangeFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _LogUi.gray200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: DropdownButton<DbChangeFilter>(
          value: filter,
          dropdownColor: Colors.white,
          iconEnabledColor: _LogUi.gray700,
          style: textTheme.labelLarge?.copyWith(
            color: _LogUi.gray950,
            fontWeight: FontWeight.w700,
          ),
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(8),
          items: [
            for (final item in DbChangeFilter.values)
              DropdownMenuItem(
                value: item,
                child: Text(item.label),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              ref.read(dbChangeFilterProvider.notifier).setFilter(value);
            }
          },
        ),
      ),
    );
  }
}

class _LogsList extends ConsumerWidget {
  const _LogsList({required this.mode, required this.selectedDate});

  final LogsViewMode mode;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (mode) {
      case LogsViewMode.audioPipeline:
        final state = ref.watch(audioPipelineTurnsProvider(selectedDate));
        return _AsyncList(
          state: state,
          emptyText: 'No audio pipeline logs found for this day.',
          onRefresh: () {
            ref.invalidate(logsForDayProvider);
            ref.invalidate(audioPipelineTurnsProvider);
            return ref.refresh(audioPipelineTurnsProvider(selectedDate).future);
          },
          itemBuilder: (context, turn) => _AudioTurnTile(
            turn: turn,
            date: selectedDate,
          ),
        );
      case LogsViewMode.agentPipeline:
        final state = ref.watch(agentPipelineRunsProvider(selectedDate));
        return _AsyncList(
          state: state,
          emptyText: 'No agent pipeline logs found for this day.',
          onRefresh: () {
            ref.invalidate(logsForDayProvider);
            ref.invalidate(agentPipelineRunsProvider);
            return ref.refresh(agentPipelineRunsProvider(selectedDate).future);
          },
          itemBuilder: (context, run) => _AgentRunTile(
            run: run,
            date: selectedDate,
          ),
        );
      case LogsViewMode.dbChanges:
        final filter = ref.watch(dbChangeFilterProvider);
        final state = ref.watch(
          filteredDbChangeOperationsProvider(
            DbChangeOperationsFilterKey(date: selectedDate, filter: filter),
          ),
        );
        return _AsyncList(
          state: state,
          emptyText: 'No DB changes found for this day.',
          onRefresh: () {
            ref.invalidate(dbChangeOperationsProvider);
            ref.invalidate(dbChangeEventsProvider);
            ref.invalidate(dbChangeOperationsWithEventsProvider);
            ref.invalidate(dbChangeDetailProvider);
            return ref.refresh(
              dbChangeOperationsWithEventsProvider(selectedDate).future,
            );
          },
          itemBuilder: (context, operation) => _DbChangeTile(
            operation: operation,
            date: selectedDate,
          ),
        );
    }
  }
}

class _AsyncList<T> extends StatelessWidget {
  const _AsyncList({
    required this.state,
    required this.emptyText,
    required this.onRefresh,
    required this.itemBuilder,
  });

  final AsyncValue<List<T>> state;
  final String emptyText;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _ErrorPanel(error: error),
      data: (items) {
        if (items.isEmpty) return Center(child: Text(emptyText));
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) => itemBuilder(context, items[index]),
          ),
        );
      },
    );
  }
}

class _AudioTurnTile extends StatelessWidget {
  const _AudioTurnTile({required this.turn, required this.date});

  final AudioPipelineTurn turn;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final preview = turn.transcript.isNotEmpty
        ? turn.transcript
        : turn.assistant.isNotEmpty
            ? turn.assistant
            : turn.logs.last.message;
    return _LogCard(
      onTap: () => context.push(
        '/logs/audio?date=${formatLogDate(date)}&turnkey=${Uri.encodeQueryComponent(turn.turnkey)}',
      ),
      icon: Icons.graphic_eq_rounded,
      accent: _LogUi.blue,
      title: 'Turn ${_turnLabel(turn.turnkey)}',
      status: turn.status,
      subtitle: preview.isEmpty ? 'No transcript captured yet' : preview,
      meta: [
        if (turn.agentName.isNotEmpty) turn.agentName,
        '${turn.logs.length} rows',
        _formatDuration(turn.durationMs),
        _formatTimeMs(turn.lastMs),
      ],
      stageStates: turn.stages.map((stage) => stage.state).toList(),
    );
  }
}

class _AgentRunTile extends StatelessWidget {
  const _AgentRunTile({required this.run, required this.date});

  final AgentPipelineRun run;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final label = run.agentName.isNotEmpty
        ? run.agentName
        : run.agentId.isNotEmpty
            ? run.agentId
            : 'Agent';
    final preview = run.userText.isNotEmpty
        ? run.userText
        : run.response.isNotEmpty
            ? run.response
            : run.logs.last.message;
    return _LogCard(
      onTap: () => context.push(
        '/logs/agent/${Uri.encodeComponent(run.runId)}?date=${formatLogDate(date)}',
      ),
      icon: Icons.account_tree_rounded,
      accent: _LogUi.violet,
      title:
          '$label ${run.runId.substring(0, run.runId.length < 8 ? run.runId.length : 8)}',
      status: run.status,
      subtitle: preview.isEmpty ? 'No prompt captured yet' : preview,
      meta: [
        if (run.clientApp.isNotEmpty) run.clientApp,
        '${run.toolCalls} tools',
        '${run.changeOperationIds.length} DB changes',
        _formatDuration(run.durationMs),
      ],
    );
  }
}

class _DbChangeTile extends StatelessWidget {
  const _DbChangeTile({required this.operation, required this.date});

  final DbChangeOperation operation;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final status = operation.reversalOfOperationId.isNotEmpty
        ? 'reversal'
        : operation.reversedByOperationId.isNotEmpty
            ? 'reversed'
            : 'active';
    final title = operation.sourceLabel.isNotEmpty
        ? operation.sourceLabel
        : operation.sourceId.isNotEmpty
            ? operation.sourceId
            : operation.id;
    return _LogCard(
      onTap: () => context.push(
        '/logs/db/${Uri.encodeComponent(operation.id)}?date=${formatLogDate(date)}',
      ),
      icon: Icons.storage_rounded,
      accent: _LogUi.orange,
      title: title,
      status: status,
      subtitle: operation.sourceKind.isEmpty
          ? 'Unknown source'
          : '${operation.sourceKind}${operation.sourceId.isEmpty ? '' : ' / ${operation.sourceId}'}',
      meta: [
        'open for row changes',
        _formatDateTime(operation.createdAt),
        operation.id
            .substring(0, operation.id.length < 8 ? operation.id.length : 8),
      ],
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.onTap,
    required this.icon,
    required this.accent,
    required this.title,
    required this.status,
    required this.subtitle,
    required this.meta,
    this.stageStates = const [],
  });

  final VoidCallback onTap;
  final IconData icon;
  final Color accent;
  final String title;
  final String status;
  final String subtitle;
  final List<String> meta;
  final List<String> stageStates;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _LogUi.gray200),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: accent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              color: _LogUi.gray950,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final item
                                  in meta.where((item) => item.isNotEmpty))
                                _MetaChip(text: item),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StatusChip(status: status),
                  ],
                ),
                if (stageStates.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final state in stageStates)
                        Expanded(
                          child: Container(
                            height: 5,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: _stageColor(state),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: _LogUi.gray600,
                    height: 1.35,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          status.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border.all(color: _LogUi.gray200),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: _LogUi.gray600,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Failed to load logs:\n$error',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'complete':
    case 'active':
      return Colors.green.shade700;
    case 'failed':
      return Colors.red.shade700;
    case 'partial':
    case 'reversed':
    case 'reversal':
      return Colors.orange.shade800;
    case 'incomplete':
      return Colors.blue.shade700;
    default:
      return Colors.blueGrey.shade700;
  }
}

abstract final class _LogUi {
  static const gray50 = Color(0xFFF9FAFB);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray600 = Color(0xFF4B5563);
  static const gray700 = Color(0xFF374151);
  static const gray950 = Color(0xFF030712);
  static const blue = Color(0xFF2563EB);
  static const violet = Color(0xFF7C3AED);
  static const orange = Color(0xFFEA580C);
}

Color _stageColor(String state) {
  switch (state) {
    case 'done':
      return Colors.green.shade600;
    case 'error':
      return Colors.red.shade600;
    default:
      return Colors.grey.shade300;
  }
}

String _turnLabel(String turnkey) {
  final parts = turnkey.split(':');
  if (parts.length >= 2) return '${parts[1]} nonce ${parts[0]}';
  return turnkey;
}

String _formatTimeMs(int ms) {
  if (ms <= 0) return '';
  return _formatTime(DateTime.fromMillisecondsSinceEpoch(ms));
}

String _formatDateTime(DateTime? value) =>
    value == null ? '' : _formatTime(value);

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
