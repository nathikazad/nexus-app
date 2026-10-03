import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/action/action.dart' as domain;
import 'package:nx_time/features/action_detail/action_detail_page.dart';
import 'package:nx_time/features/action_detail/action_detail_view_model.dart';

final selectedDayActionsProvider = FutureProvider.autoDispose
    .family<List<domain.Action>, DateTime>((ref, day) async {
      final w = await ref.watch(timeDomainsProvider.future);
      final rows = await Future.wait(
        w.selectedIds.map((id) async {
          final actions = await w.actions(id).listForCalendarDay(day);
          w.remember(id, actions.map((a) => a.id));
          return actions;
        }),
      );
      return rows.expand((a) => a).toList()
        ..sort((a, b) => (a.startTime ?? day).compareTo(b.startTime ?? day));
    });

/// The Goals heatmap drills into activity across the selected domains.
class DomainDayActionsPage extends ConsumerWidget {
  const DomainDayActionsPage({super.key, required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = modelTypeColorsOrFallback(
      ref.watch(modelTypeColorsProvider),
    );
    return Scaffold(
      appBar: AppBar(title: Text(DateFormat.MMMEd().format(date))),
      body: ref
          .watch(selectedDayActionsProvider(date))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load activity: $e')),
            data: (actions) => actions.isEmpty
                ? const Center(
                    child: Text('No activity in the selected domains'),
                  )
                : ListView(
                    children: [
                      for (final action in actions)
                        ListTile(
                          title: Text(action.name),
                          subtitle: Text(
                            [
                              ref
                                      .watch(timeDomainsProvider)
                                      .requireValue
                                      .nameFor(action.id) ??
                                  '',
                              if (action.startTime != null)
                                DateFormat.jm().format(action.startTime!),
                            ].join(' · '),
                          ),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ActivityDetailPage(
                                  args: activityDetailArgsForAction(
                                    action,
                                    DateFormat.MMMEd().format(date),
                                    colors,
                                  ),
                                ),
                              ),
                            );
                            ref.invalidate(selectedDayActionsProvider(date));
                          },
                        ),
                    ],
                  ),
          ),
    );
  }
}
