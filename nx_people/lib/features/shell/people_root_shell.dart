import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_people/core/layout/is_desktop_layout.dart';
import 'package:nx_people/core/theme/app_theme.dart';
import 'package:nx_people/data/providers.dart';
import 'package:nx_people/domain/person/person.dart';
import 'package:nx_people/domain/person/person_query.dart';
import 'package:nx_people/features/shell/people_state.dart';

const _softInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
  borderSide: BorderSide(color: Colors.transparent),
);

const _focusedSoftInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
  borderSide: BorderSide(color: AppColors.lineStrong),
);

void _invalidatePeopleData(WidgetRef ref, {int? personId}) {
  ref.invalidate(recentPeopleProvider);
  ref.invalidate(pinnedPeopleProvider);
  ref.invalidate(followUpPeopleProvider);
  ref.invalidate(companiesProvider);
  ref.invalidate(peopleTagSystemsProvider);
  ref.invalidate(_searchPeopleProvider);
  if (personId != null) {
    ref.invalidate(personByIdProvider(personId));
  }
}

Future<void> _showPersonForm(BuildContext context, {Person? person}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FractionallySizedBox(
      heightFactor: MediaQuery.sizeOf(context).height < 700 ? 0.95 : 0.85,
      child: _PersonFormSheet(person: person),
    ),
  );
}

class PeopleRootShell extends ConsumerWidget {
  const PeopleRootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(peopleWorkspaceProvider);
    final desktop = isDesktopLayout(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: desktop,
        child: desktop
            ? const _DesktopWorkspace()
            : _MobileWorkspace(section: workspace.section),
      ),
      bottomNavigationBar: desktop ? null : const _BottomTabs(),
    );
  }
}

class _DesktopWorkspace extends ConsumerWidget {
  const _DesktopWorkspace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(peopleWorkspaceProvider).section;
    return Row(
      children: <Widget>[
        const _SideNav(),
        Expanded(child: _SectionBody(section: section, desktop: true)),
      ],
    );
  }
}

class _MobileWorkspace extends StatelessWidget {
  const _MobileWorkspace({required this.section});

  final PeopleAppSection section;

  @override
  Widget build(BuildContext context) {
    return _SectionBody(section: section, desktop: false);
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.section, required this.desktop});

  final PeopleAppSection section;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      PeopleAppSection.people => _PeopleView(desktop: desktop),
      PeopleAppSection.meetings => _MeetingsView(desktop: desktop),
      PeopleAppSection.pending => const _PlaceholderView(
        icon: Icons.inbox_outlined,
        title: 'Pending',
        body:
            'Follow-ups, promises, intros, and waiting-on-me items will live here.',
      ),
      PeopleAppSection.funnels => const _PlaceholderView(
        icon: Icons.filter_alt_outlined,
        title: 'Funnels',
        body:
            'Customer, engineer hire, investor, and other relationship pipelines will live here.',
      ),
    };
  }
}

class _SideNav extends ConsumerWidget {
  const _SideNav();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(peopleWorkspaceProvider).section;
    return Container(
      width: 244,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
            child: Text(
              'nx_people',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: <Widget>[
                for (final item in _navItems)
                  _NavButton(item: item, selected: selected == item.section),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              children: <Widget>[
                _InitialsBadge(initials: 'ME', size: 32),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'My Profile',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Settings',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends ConsumerWidget {
  const _NavButton({required this.item, required this.selected});

  final _NavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.subtle : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => ref
              .read(peopleWorkspaceProvider.notifier)
              .setSection(item.section),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: <Widget>[
                Icon(
                  item.icon,
                  size: 19,
                  color: selected ? AppColors.text : AppColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? AppColors.text : AppColors.muted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                if (item.badge != null)
                  _CountBadge(
                    label: item.badge!,
                    urgent: item.section == PeopleAppSection.pending,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PeopleView extends ConsumerWidget {
  const _PeopleView({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(peopleWorkspaceProvider).searchText;
    final peopleValue = query.trim().isEmpty
        ? ref.watch(recentPeopleProvider)
        : ref.watch(_searchPeopleProvider(query));
    return peopleValue.when(
      data: (people) {
        _selectFirstPersonIfNeeded(ref, people);
        final filtered = _filterPeople(people, query);
        final activeId = ref.watch(peopleWorkspaceProvider).activePersonId;
        final active =
            _personById(filtered, activeId) ?? _personById(people, activeId);

        if (desktop) {
          return Row(
            children: <Widget>[
              SizedBox(width: 420, child: _PeopleList(people: filtered)),
              const VerticalDivider(width: 1),
              Expanded(
                child: active == null
                    ? const _EmptyDetail()
                    : _PersonDetail(person: active, desktop: true),
              ),
            ],
          );
        }

        return _PeopleList(people: filtered, fullHeight: true);
      },
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _PeopleList extends ConsumerWidget {
  const _PeopleList({required this.people, this.fullHeight = false});

  final List<Person> people;
  final bool fullHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(peopleWorkspaceProvider).activePersonId;
    final pinned = people.where((person) => person.pinned).toList();
    final followUp = people
        .where((person) => person.status.toLowerCase().contains('follow'))
        .toList();

    return Column(
      children: <Widget>[
        _ViewHeader(
          title: 'People',
          actionIcon: Icons.add,
          actionKey: const ValueKey('people-add-button'),
          onActionPressed: () => _showPersonForm(context),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const ValueKey('people-search-field'),
                  onChanged: ref
                      .read(peopleWorkspaceProvider.notifier)
                      .setSearchText,
                  decoration: InputDecoration(
                    hintText: 'Search everyone...',
                    prefixIcon: const Icon(Icons.search, size: 19),
                    fillColor: fullHeight
                        ? AppColors.subtle.withValues(alpha: 0.62)
                        : AppColors.panel,
                    border: fullHeight ? _softInputBorder : null,
                    enabledBorder: fullHeight ? _softInputBorder : null,
                    focusedBorder: fullHeight ? _focusedSoftInputBorder : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const _FilterIconButton(),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 10, 16, fullHeight ? 96 : 24),
            children: <Widget>[
              const _FilterRow(
                labels: <String>['Pinned', 'Recent', 'Follow up'],
              ),
              SizedBox(height: fullHeight ? 8 : 6),
              if (fullHeight)
                for (final person in people)
                  _PersonRow(person: person, selected: person.id == activeId)
              else ...<Widget>[
                if (pinned.isNotEmpty)
                  _PeopleGroup(
                    title: 'Pinned',
                    people: pinned,
                    activeId: activeId,
                  ),
                _PeopleGroup(
                  title: 'Recently contacted',
                  people: people,
                  activeId: activeId,
                ),
                if (followUp.isNotEmpty)
                  _PeopleGroup(
                    title: 'Needs follow-up',
                    people: followUp,
                    activeId: activeId,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PeopleGroup extends StatelessWidget {
  const _PeopleGroup({
    required this.title,
    required this.people,
    required this.activeId,
  });

  final String title;
  final List<Person> people;
  final int? activeId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionLabel(title),
          const SizedBox(height: 8),
          for (final person in people)
            _PersonRow(person: person, selected: person.id == activeId),
        ],
      ),
    );
  }
}

class _PersonRow extends ConsumerWidget {
  const _PersonRow({required this.person, required this.selected});

  final Person person;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = isDesktopLayout(context);
    final selectedStyle = selected && desktop;
    final subtitle = _personListSubtitle(person);
    final pending = _personHasPending(person);
    final timestamp = _personListTimestamp(person);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selectedStyle ? AppColors.panel : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        elevation: selectedStyle ? 1 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            ref.read(peopleWorkspaceProvider.notifier).openPerson(person.id);
            if (!desktop) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _PersonDetailPage(personId: person.id),
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: selectedStyle ? AppColors.line : Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _PersonAvatar(person: person, size: 48),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        person.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (timestamp != null || pending) ...<Widget>[
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      if (timestamp != null)
                        Text(
                          timestamp,
                          style: const TextStyle(
                            color: AppColors.faint,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (pending) ...<Widget>[
                        if (timestamp != null) const SizedBox(height: 8),
                        _StatusDot(
                          key: ValueKey('person-pending-dot-${person.id}'),
                          color: const Color(0xffd97757),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonDetailPage extends ConsumerWidget {
  const _PersonDetailPage({required this.personId});

  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personValue = ref.watch(personByIdProvider(personId));
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: personValue.when(
          data: (person) {
            if (person == null) {
              return const Center(child: Text('Person not found.'));
            }
            return Column(
              children: <Widget>[
                _ProfileTopBar(person: person),
                Expanded(child: _PersonDetail(person: person, desktop: false)),
              ],
            );
          },
          error: (error, stackTrace) => Center(child: Text('$error')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _ProfileTopBar extends ConsumerWidget {
  const _ProfileTopBar({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, size: 20),
            color: AppColors.muted,
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.muted,
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'PROFILE',
              style: TextStyle(
                color: AppColors.faint,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _showPersonForm(context, person: person),
            child: const Text('Edit'),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz, size: 20),
            color: AppColors.muted,
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonDetail extends StatelessWidget {
  const _PersonDetail({required this.person, required this.desktop});

  final Person person;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        desktop ? 44 : 22,
        28,
        desktop ? 44 : 22,
        80,
      ),
      children: <Widget>[
        _ProfileHeader(
          person: person,
          onEdit: desktop
              ? () => _showPersonForm(context, person: person)
              : null,
        ),
        const SizedBox(height: 24),
        _DividerBand(
          left: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final tag in person.tags.take(4)) _TinyChip(tag),
            ],
          ),
          right: const Wrap(
            spacing: 8,
            children: <Widget>[
              _IconBox(icon: Icons.mail_outline),
              _IconBox(icon: Icons.phone_outlined),
              _IconBox(icon: Icons.link_outlined),
            ],
          ),
        ),
        const SizedBox(height: 26),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumn = constraints.maxWidth > 560;
            final children = <Widget>[
              _NextActionCard(person: person),
              _ActiveFunnelCard(person: person),
            ];
            if (!twoColumn) {
              return Column(
                children: <Widget>[
                  for (final child in children)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: child,
                    ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final child in children) ...<Widget>[
                  Expanded(child: child),
                  if (child != children.last) const SizedBox(width: 16),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        _DetailSection(
          icon: Icons.history,
          title: 'Timeline and meetings',
          child: Column(
            children: <Widget>[
              for (final log in person.logs)
                _TimelineRow(
                  label: log.time,
                  title: log.time == 'Today'
                      ? 'Today note'
                      : 'Relationship note',
                  body: log.body,
                ),
              for (final meeting in person.meetings.take(2))
                _TimelineRow(
                  label: 'Meeting',
                  title: meeting,
                  body: 'Conversation with ${person.name}.',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.person, this.onEdit});

  final Person person;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PersonAvatar(person: person, size: 78),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                person.name,
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    person.role,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const _SmallDot(),
                  Text(
                    person.company,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const _SmallDot(),
                  Text(
                    person.location,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                person.summary,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        if (onEdit != null) ...<Widget>[
          const SizedBox(width: 12),
          IconButton.outlined(
            key: ValueKey('person-edit-button-${person.id}'),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit person',
          ),
        ],
      ],
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final thread = person.currentThreads.firstOrNull;
    return _InfoPanel(
      icon: Icons.inbox_outlined,
      title: 'Next action',
      urgent: person.status.toLowerCase().contains('follow'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            thread?.title ?? 'No open action',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            thread?.body ?? 'Nothing pending with this person right now.',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'Due: ${person.nextFollowUp}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('Snooze')),
              FilledButton(onPressed: () {}, child: const Text('Done')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveFunnelCard extends StatelessWidget {
  const _ActiveFunnelCard({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final funnel = person.tags.contains('Investor')
        ? 'Investor'
        : person.role.toLowerCase().contains('engineer')
        ? 'Engineer hire'
        : 'Relationship';
    return _InfoPanel(
      icon: Icons.filter_alt_outlined,
      title: 'Active funnel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const _StatusDot(color: AppColors.green),
              const SizedBox(width: 8),
              Text(
                funnel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Stage: Active conversation',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              for (var index = 0; index < 5; index++)
                Expanded(
                  child: Container(
                    height: 6,
                    margin: EdgeInsets.only(right: index == 4 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: index < 3 ? AppColors.green : AppColors.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeetingsView extends ConsumerWidget {
  const _MeetingsView({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleValue = ref.watch(recentPeopleProvider);
    return peopleValue.when(
      data: (people) {
        final offset = ref.watch(peopleWorkspaceProvider).selectedDayOffset;
        final items = _agendaFor(people, offset);
        final selectedPerson = ref
            .watch(peopleWorkspaceProvider)
            .activePersonId;
        final activePerson =
            _personById(people, selectedPerson) ?? people.firstOrNull;

        if (desktop) {
          return Row(
            children: <Widget>[
              SizedBox(
                width: 460,
                child: _MeetingAgenda(items: items, selectedDayOffset: offset),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: activePerson == null
                    ? const _EmptyDetail()
                    : _PersonDetail(person: activePerson, desktop: true),
              ),
            ],
          );
        }

        return _MeetingAgenda(
          items: items,
          selectedDayOffset: offset,
          fullHeight: true,
        );
      },
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _MeetingAgenda extends StatelessWidget {
  const _MeetingAgenda({
    required this.items,
    required this.selectedDayOffset,
    this.fullHeight = false,
  });

  final List<_AgendaItem> items;
  final int selectedDayOffset;
  final bool fullHeight;

  @override
  Widget build(BuildContext context) {
    final meetings = items
        .where((item) => item.kind == _AgendaKind.meeting)
        .length;
    final checkIns = items
        .where((item) => item.kind == _AgendaKind.checkIn)
        .length;
    return Column(
      children: <Widget>[
        _ViewHeader(
          title: 'Meetings',
          actionIcon: Icons.add,
          child: fullHeight
              ? _MobileMeetingDateCard(
                  selectedOffset: selectedDayOffset,
                  meetings: meetings,
                  checkIns: checkIns,
                )
              : _DateStrip(selectedOffset: selectedDayOffset),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, fullHeight ? 96 : 24),
            children: <Widget>[
              if (!fullHeight) ...<Widget>[
                _SummaryRow(
                  cells: <_SummaryCell>[
                    _SummaryCell('$meetings', 'Meetings'),
                    _SummaryCell('$checkIns', 'Check-ins'),
                    _SummaryCell('${items.length}', 'People touched'),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              _SectionLabel(
                selectedDayOffset == 0
                    ? "Today's agenda"
                    : '${_dayTitle(selectedDayOffset)} agenda',
              ),
              const SizedBox(height: 10),
              if (items.isEmpty)
                const _EmptyPanel(
                  title: 'No meetings on this day',
                  body:
                      'Use the date strip to browse past notes and upcoming check-ins.',
                )
              else
                for (final item in items) _AgendaRow(item: item),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileMeetingDateCard extends ConsumerWidget {
  const _MobileMeetingDateCard({
    required this.selectedOffset,
    required this.meetings,
    required this.checkIns,
  });

  final int selectedOffset;
  final int meetings;
  final int checkIns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateTime.now().add(Duration(days: selectedOffset));
    final title = selectedOffset == 0
        ? 'Today, ${_month(date.month)} ${date.day}'
        : '${_dayTitle(selectedOffset)}, ${_month(date.month)} ${date.day}';
    final notifier = ref.read(peopleWorkspaceProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.subtle.withValues(alpha: 0.62),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          _SoftIconButton(
            icon: Icons.chevron_left,
            onTap: () => notifier.setSelectedDayOffset(selectedOffset - 1),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$meetings Meetings • $checkIns Follow-ups',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.faint,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _SoftIconButton(
            icon: Icons.calendar_today_outlined,
            onTap: () => notifier.setSelectedDayOffset(0),
          ),
          const SizedBox(width: 6),
          _SoftIconButton(
            icon: Icons.chevron_right,
            onTap: () => notifier.setSelectedDayOffset(selectedOffset + 1),
          ),
        ],
      ),
    );
  }
}

class _SoftIconButton extends StatelessWidget {
  const _SoftIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 18, color: AppColors.muted),
        ),
      ),
    );
  }
}

class _DateStrip extends ConsumerWidget {
  const _DateStrip({required this.selectedOffset});

  final int selectedOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (var offset = -3; offset <= 3; offset++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _DateButton(
                offset: offset,
                selected: offset == selectedOffset,
                onTap: () => ref
                    .read(peopleWorkspaceProvider.notifier)
                    .setSelectedDayOffset(offset),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.offset,
    required this.selected,
    required this.onTap,
  });

  final int offset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.now().add(Duration(days: offset));
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.text : AppColors.subtle,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.text : AppColors.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              offset == 0 ? 'Today' : _weekday(date.weekday),
              style: TextStyle(
                color: selected ? AppColors.bg : AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}',
              style: TextStyle(
                color: selected ? AppColors.bg : AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaRow extends ConsumerWidget {
  const _AgendaRow({required this.item});

  final _AgendaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            ref
                .read(peopleWorkspaceProvider.notifier)
                .openPerson(item.person.id);
            if (!isDesktopLayout(context)) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _PersonDetailPage(personId: item.person.id),
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _AgendaIcon(kind: item.kind),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            item.time,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: <Widget>[
                          _PersonAvatar(person: item.person, size: 24),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              item.person.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _PlaceholderView extends StatelessWidget {
  const _PlaceholderView({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _EmptyPanel(title: title, body: body, icon: icon),
        ),
      ),
    );
  }
}

class _BottomTabs extends ConsumerWidget {
  const _BottomTabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(peopleWorkspaceProvider).section;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.94),
        border: const Border(top: BorderSide(color: AppColors.line)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              for (final item in _navItems)
                _BottomTabButton(
                  item: item,
                  selected: selected == item.section,
                  onTap: () => ref
                      .read(peopleWorkspaceProvider.notifier)
                      .setSection(item.section),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomTabButton extends StatelessWidget {
  const _BottomTabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: <Widget>[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  item.icon,
                  size: 24,
                  color: selected ? AppColors.text : AppColors.faint,
                ),
                const SizedBox(height: 5),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.text : AppColors.faint,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (item.section == PeopleAppSection.pending)
              const Positioned(top: 18, right: 22, child: _PendingDot()),
          ],
        ),
      ),
    );
  }
}

class _PendingDot extends StatelessWidget {
  const _PendingDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xffd97757),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.panel, width: 2),
      ),
    );
  }
}

class _ViewHeader extends StatelessWidget {
  const _ViewHeader({
    required this.title,
    required this.actionIcon,
    required this.child,
    this.actionKey,
    this.onActionPressed,
  });

  final String title;
  final IconData actionIcon;
  final Widget child;
  final Key? actionKey;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton.filled(
                key: actionKey,
                onPressed: onActionPressed,
                icon: Icon(actionIcon, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PersonFormSheet extends ConsumerStatefulWidget {
  const _PersonFormSheet({this.person});

  final Person? person;

  @override
  ConsumerState<_PersonFormSheet> createState() => _PersonFormSheetState();
}

class _PersonFormSheetState extends ConsumerState<_PersonFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _companyController;
  late final TextEditingController _summaryController;
  bool _saving = false;

  bool get _editing => widget.person != null;

  @override
  void initState() {
    super.initState();
    final person = widget.person;
    _nameController = TextEditingController(text: person?.name ?? '');
    _companyController = TextEditingController(text: person?.company ?? '');
    _summaryController = TextEditingController(text: person?.summary ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final draft = PersonDraft(
      name: _nameController.text.trim(),
      company: _companyController.text.trim(),
      summary: _summaryController.text.trim(),
    );

    try {
      final repository = ref.read(peopleRepositoryProvider);
      final existing = widget.person;
      final id = existing == null
          ? await repository.createPerson(draft)
          : existing.id;

      if (existing != null) {
        await repository.updatePerson(existing.id, draft);
      }

      _invalidatePeopleData(ref, personId: id);
      ref.read(peopleWorkspaceProvider.notifier).openPerson(id);

      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save person: $error'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _editing ? 'Edit Person' : 'Add Person',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20),
                      color: AppColors.muted,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _PersonFormField(
                          fieldKey: const ValueKey('person-name-field'),
                          controller: _nameController,
                          label: 'Name',
                          hint: 'Person name',
                          icon: Icons.person_outline,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        _PersonFormField(
                          fieldKey: const ValueKey('person-company-field'),
                          controller: _companyController,
                          label: 'Company',
                          hint: 'Company',
                          icon: Icons.business_outlined,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 18),
                        _PersonFormField(
                          fieldKey: const ValueKey('person-summary-field'),
                          controller: _summaryController,
                          label: 'Notes',
                          hint: 'What should you remember?',
                          icon: Icons.notes_outlined,
                          minLines: 4,
                          maxLines: 6,
                          textInputAction: TextInputAction.newline,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
                decoration: const BoxDecoration(
                  color: AppColors.bg,
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('person-save-button'),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.bg,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonFormField extends StatelessWidget {
  const _PersonFormField({
    this.fieldKey,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.textInputAction,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: AppColors.faint,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: fieldKey,
          controller: controller,
          validator: validator,
          minLines: minLines,
          maxLines: maxLines,
          textInputAction: textInputAction,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 19),
            fillColor: AppColors.panel,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: AppColors.line),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: AppColors.line),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: AppColors.lineStrong),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const ValueKey('people-filter-button'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const FractionallySizedBox(
            heightFactor: 0.85,
            child: _PeopleFilterSheet(),
          ),
        ),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.tune, color: AppColors.muted, size: 19),
        ),
      ),
    );
  }
}

class _PeopleFilterSheet extends StatelessWidget {
  const _PeopleFilterSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Filter & Sort',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.muted,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(22, 22, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _FilterSection(label: 'Sort By', child: _SortSelector()),
                    SizedBox(height: 26),
                    _FilterSection(
                      label: 'Company',
                      child: _FilterTextField(
                        icon: Icons.business_outlined,
                        hint: 'Search company...',
                      ),
                    ),
                    SizedBox(height: 26),
                    _FilterSection(
                      label: 'Role',
                      child: _FilterTextField(
                        icon: Icons.badge_outlined,
                        hint: 'Search role...',
                      ),
                    ),
                    SizedBox(height: 26),
                    _FilterSection(
                      label: 'Tags',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _FilterTextField(
                            icon: Icons.sell_outlined,
                            hint: 'Search tags...',
                          ),
                          SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              _SelectedFilterChip('Top Tier'),
                              _SelectedFilterChip('SF Bay Area'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
              decoration: const BoxDecoration(
                color: AppColors.bg,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: AppColors.faint,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _SortSelector extends StatelessWidget {
  const _SortSelector();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.subtle.withValues(alpha: 0.8),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: <Widget>[
          Expanded(child: _SortOption(label: 'Name', selected: true)),
          Expanded(child: _SortOption(label: 'Last Meeting')),
        ],
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.panel : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        boxShadow: selected
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 5,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.text : AppColors.muted,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _FilterTextField extends StatelessWidget {
  const _FilterTextField({required this.icon, required this.hint});

  final IconData icon;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 19),
        fillColor: AppColors.panel,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.line),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.line),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.lineStrong),
        ),
      ),
    );
  }
}

class _SelectedFilterChip extends StatelessWidget {
  const _SelectedFilterChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.subtle,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.close, size: 14, color: AppColors.faint),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (final label in labels)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _PeopleFilterPill(label),
            ),
        ],
      ),
    );
  }
}

class _PeopleFilterPill extends StatelessWidget {
  const _PeopleFilterPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.subtle.withValues(alpha: 0.72),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.cells});

  final List<_SummaryCell> cells;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final cell in cells) ...<Widget>[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.panel,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    cell.value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    cell.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (cell != cells.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.child,
    this.urgent = false,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: urgent ? AppColors.amber : AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PanelTitle(icon: icon, title: title),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PanelTitle(icon: icon, title: title),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 7),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.title,
    required this.body,
  });

  final String label;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 0, 0, 0),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.subtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.4,
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

class _DividerBand extends StatelessWidget {
  const _DividerBand({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: left),
          const SizedBox(width: 12),
          right,
        ],
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: _EmptyPanel(
        title: 'Select a person',
        body:
            'Open someone from the list to see their profile, timeline, meetings, and next action.',
        icon: Icons.person_outline,
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title, required this.body, this.icon});

  final String title;
  final String body;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, color: AppColors.muted),
            const SizedBox(height: 10),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _InitialsBadge extends StatelessWidget {
  const _InitialsBadge({required this.initials, required this.size});

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
        shape: BoxShape.circle,
      ),
      child: _AvatarInitialsText(initials: initials, size: size),
    );
  }
}

class _PersonAvatar extends ConsumerWidget {
  const _PersonAvatar({required this.person, required this.size});

  final Person person;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageConfig = ref.watch(peopleImageConfigProvider);
    final imageUrl = _resolvePersonImageUrl(
      person.imageUrl,
      imageConfig?.baseUrl,
    );
    if (imageUrl == null) {
      return _InitialsBadge(initials: person.initials, size: size);
    }

    final headers =
        imageConfig != null &&
            _shouldAttachPersonImageHeaders(imageUrl, imageConfig.baseUrl)
        ? imageConfig.headers
        : null;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.subtle,
        border: Border.all(color: AppColors.line),
        shape: BoxShape.circle,
      ),
      child: Image.network(
        imageUrl,
        headers: headers,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _AvatarInitialsText(initials: person.initials, size: size);
        },
        errorBuilder: (context, error, stackTrace) {
          return _AvatarInitialsText(initials: person.initials, size: size);
        },
      ),
    );
  }
}

class _AvatarInitialsText extends StatelessWidget {
  const _AvatarInitialsText({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.muted,
          fontSize: size < 30 ? 10 : 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String? _resolvePersonImageUrl(String rawUrl, String? baseUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return null;

  final parsed = Uri.tryParse(trimmed);
  final base = _parseImageBase(baseUrl);
  if (parsed == null) return null;

  if (!parsed.hasScheme) {
    return base == null ? null : base.resolve(trimmed).toString();
  }

  if (base != null && parsed.path.startsWith('/person_image_files/')) {
    return parsed
        .replace(
          scheme: base.scheme,
          host: base.host,
          port: base.hasPort ? base.port : null,
        )
        .toString();
  }

  return trimmed;
}

bool _shouldAttachPersonImageHeaders(String imageUrl, String baseUrl) {
  final image = Uri.tryParse(imageUrl);
  final base = _parseImageBase(baseUrl);
  if (image == null || base == null || !image.hasScheme) return false;
  return image.scheme == base.scheme &&
      image.host == base.host &&
      image.port == base.port;
}

Uri? _parseImageBase(String? baseUrl) {
  final trimmed = baseUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final parsed = Uri.tryParse(trimmed.replaceAll(RegExp(r'/+$'), ''));
  if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) return null;
  return parsed;
}

class _TinyChip extends StatelessWidget {
  const _TinyChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.subtle,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.subtle,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: AppColors.muted, size: 17),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _AgendaIcon extends StatelessWidget {
  const _AgendaIcon({required this.kind});

  final _AgendaKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.subtle,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        kind == _AgendaKind.meeting
            ? Icons.calendar_today
            : Icons.event_available,
        size: 18,
        color: AppColors.muted,
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label, this.urgent = false});

  final String label;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: urgent ? AppColors.amber.withValues(alpha: 0.1) : AppColors.line,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: urgent ? AppColors.amber : AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SmallDot extends StatelessWidget {
  const _SmallDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: AppColors.lineStrong,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.section,
    required this.label,
    required this.icon,
    this.badge,
  });

  final PeopleAppSection section;
  final String label;
  final IconData icon;
  final String? badge;
}

const _navItems = <_NavItem>[
  _NavItem(
    section: PeopleAppSection.people,
    label: 'People',
    icon: Icons.groups_outlined,
  ),
  _NavItem(
    section: PeopleAppSection.meetings,
    label: 'Meetings',
    icon: Icons.calendar_today_outlined,
  ),
  _NavItem(
    section: PeopleAppSection.pending,
    label: 'Pending',
    icon: Icons.inbox_outlined,
    badge: '3',
  ),
  _NavItem(
    section: PeopleAppSection.funnels,
    label: 'Funnels',
    icon: Icons.filter_alt_outlined,
  ),
];

final _searchPeopleProvider = FutureProvider.family<List<Person>, String>(
  (ref, query) => ref.watch(peopleRepositoryProvider).search(query),
);

class _SummaryCell {
  const _SummaryCell(this.value, this.label);

  final String value;
  final String label;
}

enum _AgendaKind { meeting, checkIn }

class _AgendaItem {
  const _AgendaItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.person,
    required this.kind,
  });

  final String title;
  final String subtitle;
  final String time;
  final Person person;
  final _AgendaKind kind;
}

List<Person> _filterPeople(List<Person> people, String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return people;
  return people.where((person) => person.matches(trimmed)).toList();
}

Person? _personById(List<Person> people, int? id) {
  if (id == null) return null;
  for (final person in people) {
    if (person.id == id) return person;
  }
  return null;
}

bool _personHasPending(Person person) {
  return person.status.toLowerCase().contains('follow');
}

String _personListSubtitle(Person person) {
  final company = person.company.trim();
  if (company.isEmpty) return '';
  return company;
}

String? _personListTimestamp(Person person) {
  final lastContact = person.lastContact.trim();
  if (_isMeaningfulTimestamp(lastContact)) return lastContact;
  final updatedAt = _compactUpdatedAt(person.updatedAt);
  if (updatedAt.isEmpty) return null;
  return updatedAt;
}

bool _isMeaningfulTimestamp(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.isNotEmpty &&
      normalized != 'unknown' &&
      normalized != 'none';
}

String _compactUpdatedAt(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final datePart = trimmed.split('T').first.trim();
  return datePart.isEmpty ? trimmed : datePart;
}

void _selectFirstPersonIfNeeded(WidgetRef ref, List<Person> people) {
  final state = ref.read(peopleWorkspaceProvider);
  if (state.activePersonId != null || people.isEmpty) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(peopleWorkspaceProvider.notifier).openPerson(people.first.id);
  });
}

List<_AgendaItem> _agendaFor(List<Person> people, int dayOffset) {
  if (dayOffset == 0) {
    return <_AgendaItem>[
      for (final person in people)
        if (person.logs.any((log) => log.time == 'Today'))
          _AgendaItem(
            title: person.meetings.firstOrNull ?? 'Relationship check-in',
            subtitle: 'Today touchpoint with ${person.company}',
            time: 'Today',
            person: person,
            kind: _AgendaKind.meeting,
          ),
      for (final person in people)
        if (person.nextFollowUp == 'Today')
          _AgendaItem(
            title: 'Follow up with ${person.name}',
            subtitle: person.currentThreads.firstOrNull?.title ?? 'Open loop',
            time: 'Due',
            person: person,
            kind: _AgendaKind.checkIn,
          ),
    ];
  }

  if (dayOffset > 0) {
    return <_AgendaItem>[
      for (final person in people)
        for (final planned in person.planned.take(dayOffset == 1 ? 1 : 2))
          _AgendaItem(
            title: planned,
            subtitle: 'Planned check-in with ${person.name}',
            time: dayOffset == 1 ? 'Tomorrow' : 'Upcoming',
            person: person,
            kind: _AgendaKind.checkIn,
          ),
    ].take(5).toList();
  }

  return <_AgendaItem>[
    for (final person in people)
      for (final meeting in person.meetings.take(1))
        _AgendaItem(
          title: meeting,
          subtitle: 'Past meeting with ${person.name}',
          time: person.lastContact,
          person: person,
          kind: _AgendaKind.meeting,
        ),
  ].take(5).toList();
}

String _weekday(int weekday) {
  return const <int, String>{
    DateTime.monday: 'Mon',
    DateTime.tuesday: 'Tue',
    DateTime.wednesday: 'Wed',
    DateTime.thursday: 'Thu',
    DateTime.friday: 'Fri',
    DateTime.saturday: 'Sat',
    DateTime.sunday: 'Sun',
  }[weekday]!;
}

String _month(int month) {
  return const <int, String>{
    DateTime.january: 'Jan',
    DateTime.february: 'Feb',
    DateTime.march: 'Mar',
    DateTime.april: 'Apr',
    DateTime.may: 'May',
    DateTime.june: 'Jun',
    DateTime.july: 'Jul',
    DateTime.august: 'Aug',
    DateTime.september: 'Sep',
    DateTime.october: 'Oct',
    DateTime.november: 'Nov',
    DateTime.december: 'Dec',
  }[month]!;
}

String _dayTitle(int offset) {
  if (offset == 0) return 'Today';
  if (offset == 1) return 'Tomorrow';
  if (offset == -1) return 'Yesterday';
  return offset > 0 ? 'Upcoming day' : 'Past day';
}
