import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_people/core/theme/app_theme.dart';
import 'package:nx_people/data/providers.dart';
import 'package:nx_people/domain/person/person.dart';
import 'package:nx_people/domain/person/person_query.dart';
import 'package:nx_people/features/shell/people_state.dart';

const double _sidebarWidth = 256;
const double _inspectorWidth = 288;

class DesktopShell extends ConsumerWidget {
  const DesktopShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(peopleWorkspaceProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: <Widget>[
          Row(
            children: <Widget>[
              const SizedBox(width: _sidebarWidth, child: _DesktopSidebar()),
              Expanded(child: _ProfileWorkspace(workspace: workspace)),
              SizedBox(
                width: _inspectorWidth,
                child: _Inspector(personId: workspace.activePersonId),
              ),
            ],
          ),
          if (workspace.hasOverlay)
            _ResultOverlay(contextModel: workspace.overlayContext!),
        ],
      ),
    );
  }
}

class _DesktopSidebar extends ConsumerWidget {
  const _DesktopSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(peopleWorkspaceProvider);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              const _SidebarHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                child: _SearchField(
                  onChanged: (value) async {
                    if (value.trim().length > 1) {
                      final context = await ref
                          .read(peopleRepositoryProvider)
                          .context('Search', value.trim());
                      ref
                          .read(peopleWorkspaceProvider.notifier)
                          .showOverlay(context);
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: <Widget>[
                    _SidebarTabButton(
                      label: 'People',
                      active: workspace.sidebarTab == PeopleSidebarTab.people,
                      onTap: () => ref
                          .read(peopleWorkspaceProvider.notifier)
                          .setSidebarTab(PeopleSidebarTab.people),
                    ),
                    _SidebarTabButton(
                      label: 'Tags',
                      active: workspace.sidebarTab == PeopleSidebarTab.tags,
                      onTap: () => ref
                          .read(peopleWorkspaceProvider.notifier)
                          .setSidebarTab(PeopleSidebarTab.tags),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: workspace.sidebarTab == PeopleSidebarTab.people
                    ? const _PeoplePane()
                    : const _TagsPane(),
              ),
            ],
          ),
          if (workspace.createMenuOpen)
            const Positioned(right: 12, top: 40, child: _CreateMenu()),
        ],
      ),
    );
  }
}

class _SidebarHeader extends ConsumerWidget {
  const _SidebarHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.text,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'P',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'nx_people',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              _IconSquareButton(
                tooltip: 'Create',
                icon: Icons.add,
                onPressed: () => ref
                    .read(peopleWorkspaceProvider.notifier)
                    .toggleCreateMenu(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateMenu extends StatelessWidget {
  const _CreateMenu();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(6),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: Container(
        width: 198,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _MenuTitle('Create'),
            _MenuRow('Person'),
            _MenuRow('Company'),
            _MenuRow('Meeting'),
            _MenuRow('Daily Log'),
          ],
        ),
      ),
    );
  }
}

class _MenuTitle extends StatelessWidget {
  const _MenuTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.faint,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const Spacer(),
          const Icon(Icons.chevron_right, size: 15, color: AppColors.faint),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('people-search-field'),
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(
        hintText: 'Search people...',
        prefixIcon: Icon(Icons.search, size: 18, color: AppColors.faint),
        prefixIconConstraints: BoxConstraints(minWidth: 34),
      ),
      onChanged: onChanged,
    );
  }
}

class _SidebarTabButton extends StatelessWidget {
  const _SidebarTabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: active
            ? const BoxDecoration(
                color: AppColors.panel,
                border: Border(
                  top: BorderSide(color: AppColors.line),
                  left: BorderSide(color: AppColors.line),
                  right: BorderSide(color: AppColors.line),
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.text : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _PeoplePane extends ConsumerWidget {
  const _PeoplePane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinned = ref.watch(pinnedPeopleProvider).value ?? const <Person>[];
    final recent = ref.watch(recentPeopleProvider).value ?? const <Person>[];
    final followUp =
        ref.watch(followUpPeopleProvider).value ?? const <Person>[];
    final companies = ref.watch(companiesProvider).value ?? const <String>[];
    final meetings = ref.watch(meetingsProvider).value ?? const <String>[];
    final planned = ref.watch(plannedProvider).value ?? const <String>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      children: <Widget>[
        _PersonSection(title: 'Pinned', rows: pinned),
        _PersonSection(title: 'Recent', rows: recent),
        _PersonSection(title: 'Follow up', rows: followUp),
        _QuerySection(
          title: 'Companies',
          rows: [
            for (final company in companies) _QueryRow('Company', company),
          ],
        ),
        _QuerySection(
          title: 'Meetings',
          rows: [for (final meeting in meetings) _QueryRow('Meeting', meeting)],
        ),
        _QuerySection(
          title: 'Planned',
          rows: [for (final item in planned) _QueryRow('Planned', item)],
        ),
      ],
    );
  }
}

class _TagsPane extends ConsumerWidget {
  const _TagsPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagSystems =
        ref.watch(peopleTagSystemsProvider).value ?? const <PeopleTagSystem>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      children: <Widget>[
        for (final system in tagSystems)
          _QuerySection(
            title: system.name,
            rows: [for (final tag in system.tags) _QueryRow(system.name, tag)],
          ),
      ],
    );
  }
}

class _PersonSection extends StatelessWidget {
  const _PersonSection({required this.title, required this.rows});

  final String title;
  final List<Person> rows;

  @override
  Widget build(BuildContext context) {
    return _SidebarSection(
      title: title,
      children: [for (final person in rows) _PersonSideLink(person: person)],
    );
  }
}

class _QuerySection extends StatelessWidget {
  const _QuerySection({required this.title, required this.rows});

  final String title;
  final List<_QueryRow> rows;

  @override
  Widget build(BuildContext context) {
    return _SidebarSection(title: title, children: rows);
  }
}

class _SidebarSection extends StatelessWidget {
  const _SidebarSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.faint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _PersonSideLink extends ConsumerWidget {
  const _PersonSideLink({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active =
        ref.watch(peopleWorkspaceProvider).activePersonId == person.id;
    return _SideLink(
      active: active,
      leading: _StatusDot(color: _statusColor(person.statusColor)),
      label: person.name,
      onTap: () =>
          ref.read(peopleWorkspaceProvider.notifier).openPerson(person.id),
    );
  }
}

class _QueryRow extends ConsumerWidget {
  const _QueryRow(this.type, this.label);

  final String type;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref
        .watch(_queryCountProvider((type: type, label: label)))
        .value;
    return _SideLink(
      label: label,
      trailing: count == null
          ? null
          : Text(
              '$count',
              style: const TextStyle(fontSize: 12, color: AppColors.faint),
            ),
      onTap: () async {
        final context = await ref
            .read(peopleRepositoryProvider)
            .context(type, label);
        ref.read(peopleWorkspaceProvider.notifier).showOverlay(context);
      },
    );
  }
}

final _queryCountProvider =
    FutureProvider.family<int, ({String type, String label})>(
      (ref, query) =>
          ref.watch(peopleRepositoryProvider).count(query.type, query.label),
    );

class _SideLink extends StatelessWidget {
  const _SideLink({
    required this.label,
    required this.onTap,
    this.leading,
    this.trailing,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.hover : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: active ? AppColors.text : AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileWorkspace extends ConsumerWidget {
  const _ProfileWorkspace({required this.workspace});

  final PeopleWorkspaceState workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePersonId = workspace.activePersonId;
    if (activePersonId == null) {
      return const _NoPersonSelected();
    }
    final personValue = ref.watch(personByIdProvider(activePersonId));
    return Column(
      children: <Widget>[
        if (workspace.activeContext != null)
          _ContextBar(
            contextModel: workspace.activeContext!,
            activePersonId: activePersonId,
          ),
        Expanded(
          child: personValue.when(
            data: (person) {
              if (person == null) return const _NoPersonSelected();
              return SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(48, 54, 48, 120),
                      child: _Profile(person: person),
                    ),
                  ),
                ),
              );
            },
            error: (error, stackTrace) => Center(child: Text('$error')),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }
}

class _NoPersonSelected extends ConsumerWidget {
  const _NoPersonSelected();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentPeopleProvider);
    return recent.when(
      data: (rows) {
        if (rows.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(peopleWorkspaceProvider.notifier)
                .openPerson(rows.first.id);
          });
          return const Center(child: CircularProgressIndicator());
        }
        return const Center(
          child: Text(
            'No people found in this personal domain.',
            style: TextStyle(color: AppColors.muted),
          ),
        );
      },
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ContextBar extends ConsumerWidget {
  const _ContextBar({required this.contextModel, required this.activePersonId});

  final PeopleResultContext contextModel;
  final int activePersonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = contextModel.personIds.indexOf(activePersonId);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: <Widget>[
          TextButton.icon(
            onPressed: () => ref
                .read(peopleWorkspaceProvider.notifier)
                .returnToActiveContext(),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text('Back to ${contextModel.title}'),
          ),
          const Spacer(),
          Text(
            '${index + 1} of ${contextModel.personIds.length}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          IconButton(
            tooltip: 'Clear context',
            onPressed: () =>
                ref.read(peopleWorkspaceProvider.notifier).clearActiveContext(),
            icon: const Icon(Icons.close, size: 16, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Profile extends ConsumerWidget {
  const _Profile({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Avatar(initials: person.initials, size: 56),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    person.name,
                    style: const TextStyle(
                      fontSize: 38,
                      height: 1.12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        '${person.role} · ',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                      _InlineContextButton(
                        type: 'Company',
                        label: person.company,
                      ),
                      Text(
                        ' · ${person.location}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _PillWrap(
                    children: <Widget>[
                      _Pill(
                        label: person.status,
                        leading: _StatusDot(
                          color: _statusColor(person.statusColor),
                        ),
                      ),
                      for (final tag in person.tags)
                        _ContextPill(type: 'Tag', label: tag),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _SoftButton(icon: Icons.add, label: 'Add log'),
                      _SoftButton(icon: Icons.mail_outline, label: 'Contact'),
                      _SoftButton(icon: Icons.adjust, label: 'Create meeting'),
                      _SoftButton(icon: Icons.check, label: 'Follow-up action'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        _ProfileSection(
          title: 'Summary',
          child: Text(
            person.summary,
            style: const TextStyle(
              color: Color(0xff3f3f46),
              fontSize: 15,
              height: 1.65,
            ),
          ),
        ),
        _ProfileSection(
          title: 'Current Threads',
          child: Column(
            children: <Widget>[
              for (final thread in person.currentThreads)
                _ThreadCard(title: thread.title, body: thread.body),
            ],
          ),
        ),
        _ProfileSection(
          title: 'Recent Activity',
          child: Column(
            children: <Widget>[
              for (final log in person.logs) _TimelineItem(log: log),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.log});

  final PersonLog log;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              log.time,
              style: const TextStyle(color: AppColors.faint, fontSize: 12),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Daily log',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  log.body,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Inspector extends ConsumerWidget {
  const _Inspector({required this.personId});

  final int? personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = personId;
    final personValue = id == null ? null : ref.watch(personByIdProvider(id));
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            height: 40,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              color: AppColors.sidebar,
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: const Text(
              'INSPECTOR',
              style: TextStyle(
                color: AppColors.faint,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: personValue == null
                ? const SizedBox.shrink()
                : personValue.when(
                    data: (person) {
                      if (person == null) return const SizedBox.shrink();
                      return _InspectorBody(person: person);
                    },
                    error: (error, stackTrace) => Center(child: Text('$error')),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                  ),
          ),
        ],
      ),
    );
  }
}

class _InspectorBody extends ConsumerWidget {
  const _InspectorBody({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      children: <Widget>[
        _InspectorSection(
          title: 'Details',
          children: <Widget>[
            _Pair(label: 'Status', value: person.status),
            if (person.company.isNotEmpty)
              _ContextPair(
                label: 'Company',
                type: 'Company',
                value: person.company,
              ),
            _Pair(label: 'Role', value: person.role),
            _Pair(label: 'Location', value: person.location),
            _Pair(label: 'Last contacted', value: person.lastContact),
            _Pair(label: 'Next follow-up', value: person.nextFollowUp),
          ],
        ),
        _InspectorSection(
          title: 'Contacts',
          children: <Widget>[
            _Pair(label: 'Email', value: person.email),
            _Pair(label: 'Phone', value: person.phone),
          ],
        ),
        _InspectorSection(
          title: 'Relations',
          children: <Widget>[
            for (final meeting in person.meetings)
              _LinkLine(icon: Icons.history, type: 'Meeting', label: meeting),
            for (final item in person.planned)
              _LinkLine(
                icon: Icons.radio_button_unchecked,
                type: 'Planned',
                label: item,
              ),
            for (final id in person.relatedIds)
              _RelatedPersonLink(personId: id),
          ],
        ),
        _InspectorSection(
          title: 'Tags',
          children: <Widget>[
            _PillWrap(
              children: <Widget>[
                for (final tag in person.tags)
                  _ContextPill(type: 'Tag', label: tag),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _InspectorSection extends StatelessWidget {
  const _InspectorSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.text, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextPair extends StatelessWidget {
  const _ContextPair({
    required this.label,
    required this.type,
    required this.value,
  });

  final String label;
  final String type;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _InlineContextButton(type: type, label: value),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedPersonLink extends ConsumerWidget {
  const _RelatedPersonLink({required this.personId});

  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(personByIdProvider(personId)).value;
    if (person == null) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: () =>
          ref.read(peopleWorkspaceProvider.notifier).openPerson(person.id),
      icon: const Icon(Icons.view_list, size: 15),
      label: Text(person.name),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.muted,
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _LinkLine extends ConsumerWidget {
  const _LinkLine({
    required this.icon,
    required this.type,
    required this.label,
  });

  final IconData icon;
  final String type;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: () async {
        final context = await ref
            .read(peopleRepositoryProvider)
            .context(type, label);
        ref.read(peopleWorkspaceProvider.notifier).showOverlay(context);
      },
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.muted,
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _ResultOverlay extends ConsumerWidget {
  const _ResultOverlay({required this.contextModel});

  final PeopleResultContext contextModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsValue = ref.watch(_contextPeopleProvider(contextModel));
    return Positioned.fill(
      left: _sidebarWidth,
      child: Material(
        color: Colors.white.withValues(alpha: 0.96),
        child: rowsValue.when(
          data: (rows) =>
              _ResultOverlayBody(contextModel: contextModel, rows: rows),
          error: (error, stackTrace) => Center(child: Text('$error')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

final _contextPeopleProvider =
    FutureProvider.family<List<Person>, PeopleResultContext>(
      (ref, context) => ref.watch(peopleRepositoryProvider).peopleFor(context),
    );

class _ResultOverlayBody extends ConsumerWidget {
  const _ResultOverlayBody({required this.contextModel, required this.rows});

  final PeopleResultContext contextModel;
  final List<Person> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(48, 34, 48, 56),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                contextModel.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${rows.length} people',
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(width: 16),
            _IconSquareButton(
              tooltip: 'Close results',
              icon: Icons.close,
              onPressed: () =>
                  ref.read(peopleWorkspaceProvider.notifier).hideOverlay(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PillWrap(
          children: <Widget>[
            _Pill(label: contextModel.type),
            const _Pill(label: 'Sort: recently contacted'),
          ],
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.line),
              bottom: BorderSide(color: AppColors.line),
            ),
          ),
          child: const Text(
            'Pick a person to open their profile. The profile keeps this list as a back context.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
        for (final person in rows)
          _ResultRow(person: person, contextModel: contextModel),
      ],
    );
  }
}

class _ResultRow extends ConsumerWidget {
  const _ResultRow({required this.person, required this.contextModel});

  final Person person;
  final PeopleResultContext contextModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active =
        ref.watch(peopleWorkspaceProvider).activePersonId == person.id;
    return Material(
      color: active ? AppColors.resultHover : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => ref
            .read(peopleWorkspaceProvider.notifier)
            .openPerson(person.id, context: contextModel),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              _Avatar(initials: person.initials, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      person.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${person.role} · ${person.company} · ${person.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _ResultMeta(label: 'Last contacted', value: person.lastContact),
              _ResultMeta(label: 'Next follow-up', value: person.nextFollowUp),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultMeta extends StatelessWidget {
  const _ResultMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Text.rich(
        TextSpan(
          text: '$label\n',
          children: <InlineSpan>[
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }
}

class _InlineContextButton extends ConsumerWidget {
  const _InlineContextButton({required this.type, required this.label});

  final String type;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final contextModel = await ref
            .read(peopleRepositoryProvider)
            .context(type, label);
        ref.read(peopleWorkspaceProvider.notifier).showOverlay(contextModel);
      },
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ContextPill extends ConsumerWidget {
  const _ContextPill({required this.type, required this.label});

  final String type;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Pill(
      label: label,
      onTap: () async {
        final context = await ref
            .read(peopleRepositoryProvider)
            .context(type, label);
        ref.read(peopleWorkspaceProvider.notifier).showOverlay(context);
      },
    );
  }
}

class _PillWrap extends StatelessWidget {
  const _PillWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 6, children: children);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.leading, this.onTap});

  final String label;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.subtle,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: const BoxConstraints(minHeight: 24),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.muted,
        side: const BorderSide(color: AppColors.line),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _IconSquareButton extends StatelessWidget {
  const _IconSquareButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onPressed,
          child: Container(
            width: 26,
            height: 24,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 16, color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.subtle,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(size > 40 ? 12 : 8),
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size > 40 ? 19 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

Color _statusColor(PersonStatusColor statusColor) {
  return switch (statusColor) {
    PersonStatusColor.green => AppColors.green,
    PersonStatusColor.blue => AppColors.blue,
    PersonStatusColor.amber => AppColors.amber,
    PersonStatusColor.red => AppColors.red,
  };
}
