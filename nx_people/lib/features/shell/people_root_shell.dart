import 'package:nx_people/features/assistant/people_assistant.dart';
import 'package:nx_people/features/settings/people_settings_page.dart';
import 'package:nx_people/features/events/events_page.dart';
import 'package:nx_people/features/meeting/meetings_page.dart';
import 'package:nx_people/features/meeting/meeting_card.dart';
import 'package:nx_people/features/sync/people_sync_status.dart';
import 'package:nx_people/data/sync/people_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_people/core/layout/is_desktop_layout.dart';
import 'package:nx_people/core/theme/app_theme.dart';
import 'package:nx_people/data/person/person_attr_keys.dart';
import 'package:nx_people/data/providers.dart';
import 'package:nx_people/domain/log/daily_log.dart';
import 'package:nx_people/domain/meeting/meeting_repository.dart';
import 'package:nx_people/domain/person/person.dart';
import 'package:nx_people/domain/person/person_query.dart';
import 'package:nx_people/features/shell/people_state.dart';
import 'package:url_launcher/url_launcher.dart';

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

Future<void> _showLogForm(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _LogFormSheet(),
  );
}

enum _CreateKind { person, meeting, log }

enum _AppMenuAction { logout }

Future<void> _showCreateMenu(BuildContext context) async {
  final selection = await showModalBottomSheet<_CreateKind>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => const _CreateMenuSheet(),
  );
  if (!context.mounted || selection == null) return;
  switch (selection) {
    case _CreateKind.person:
      return _showPersonForm(context);
    case _CreateKind.meeting:
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const _MeetingFormSheet(),
      );
    case _CreateKind.log:
      return _showLogForm(context);
  }
}

Future<void> _showAppMenu(BuildContext context, WidgetRef ref) async {
  final action = await showModalBottomSheet<_AppMenuAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => const _AppMenuSheet(),
  );
  if (action == null) return;
  switch (action) {
    case _AppMenuAction.logout:
      await ref.read(authProvider.notifier).logout();
      return;
  }
}

class PeopleRootShell extends ConsumerWidget {
  const PeopleRootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.isLoading || auth.value == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final workspace = ref.watch(peopleWorkspaceProvider);
    final desktop = isDesktopLayout(context);
    final selectedPerson =
        desktop &&
            workspace.section == PeopleAppSection.people &&
            workspace.activePersonId != null
        ? ref.watch(personByIdProvider(workspace.activePersonId!)).value
        : null;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: desktop,
        child: Column(
          children: [
            const PeopleSyncStatus(),
            Expanded(
              child: desktop
                  ? const _DesktopWorkspace()
                  : _MobileWorkspace(section: workspace.section),
            ),
          ],
        ),
      ),
      bottomNavigationBar: desktop ? null : const _BottomTabs(),
      floatingActionButton: desktop
          ? PeopleAssistantButton(
              selection: selectedPerson == null
                  ? null
                  : PeopleAssistantContext(
                      kind: 'Person',
                      id: selectedPerson.id,
                      name: selectedPerson.name,
                    ),
            )
          : null,
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
      PeopleAppSection.meetings => MeetingsPage(
        onCreate: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _MeetingFormSheet(),
        ),
      ),
      PeopleAppSection.events => const EventsPage(),
      PeopleAppSection.settings => const PeopleSettingsPage(),
      PeopleAppSection.logs => _LogsView(desktop: desktop),
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
          Padding(
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _showAppMenu(context, ref),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.text,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.menu, size: 19),
                    SizedBox(width: 12),
                    Text('Menu'),
                  ],
                ),
              ),
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
      skipLoadingOnReload: true,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 16, 24),
          child: Row(
            children: [
              Expanded(child: Text('People', style: peopleEditorialTitle(30))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(100),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: TextField(
              key: const ValueKey('people-search-field'),
              style: const TextStyle(fontSize: 14),
              onChanged: ref
                  .read(peopleWorkspaceProvider.notifier)
                  .setSearchText,
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: Color(0xffa3a09a),
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 16, right: 12),
                  child: CustomPaint(
                    size: Size(20, 20),
                    painter: _SearchIconPainter(),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 48,
                  maxWidth: 48,
                  minHeight: 20,
                  maxHeight: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: const BorderSide(color: AppColors.green),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            key: const PageStorageKey('people-list'),
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            children: [
              for (final person in people)
                _PersonRow(person: person, selected: person.id == activeId),
            ],
          ),
        ),
      ],
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
    return Padding(
      padding: EdgeInsets.zero,
      child: Material(
        color: selectedStyle ? AppColors.panel : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
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
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _PersonAvatar(person: person, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        person.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
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
                            fontSize: 14,
                          ),
                        ),
                      ],
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

class _PersonDetailPage extends ConsumerWidget {
  const _PersonDetailPage({required this.personId});

  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personValue = ref.watch(personByIdProvider(personId));
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: personValue.value == null
          ? null
          : PeopleAssistantButton(
              selection: PeopleAssistantContext(
                kind: 'Person',
                id: personId,
                name: personValue.value!.name,
              ),
            ),
      body: SafeArea(
        child: personValue.when(
          skipLoadingOnReload: true,
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
      decoration: const BoxDecoration(color: AppColors.bg),
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
          const Spacer(),
          TextButton(
            onPressed: () => _showPersonForm(context, person: person),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

class _PersonDetail extends StatefulWidget {
  const _PersonDetail({required this.person, required this.desktop});

  final Person person;
  final bool desktop;

  @override
  State<_PersonDetail> createState() => _PersonDetailState();
}

class _PersonDetailState extends State<_PersonDetail> {
  _ProfileDetailTab _selectedTab = _ProfileDetailTab.activity;

  @override
  void didUpdateWidget(covariant _PersonDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person.id != widget.person.id) {
      _selectedTab = _ProfileDetailTab.activity;
    }
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.person;
    final desktop = widget.desktop;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        desktop ? 44 : 22,
        desktop ? 28 : 0,
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
        SizedBox(height: desktop ? 20 : 0),
        _ProfileTabBar(
          selected: _selectedTab,
          onSelected: (tab) => setState(() => _selectedTab = tab),
        ),
        SizedBox(height: desktop ? 24 : 4),
        if (_selectedTab == _ProfileDetailTab.background)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileStatement(label: 'Summary', body: person.summary),
              if (person.desires.isNotEmpty)
                _ProfileStatement(
                  label: 'Looking for',
                  body: person.desires.join(', '),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in person.tags) _TinyChip(tag),
                  Consumer(
                    builder: (context, ref, _) => _AddTagChip(
                      onTap: () => _addProfileTag(context, ref, person),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _BackgroundContent(person: person, desktop: desktop),
            ],
          )
        else
          _ActivityContent(person: person, desktop: desktop),
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
    return Consumer(
      builder: (context, ref, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final currentTitle = _profileCurrentTitle(person);
            final currentCompany = person.company.trim();
            final location = person.location.trim();
            final identityMeta = <Widget>[
              if (currentTitle.isNotEmpty)
                Text(
                  currentTitle,
                  style: const TextStyle(color: AppColors.muted),
                ),
              if (currentCompany.isNotEmpty)
                Text(
                  currentCompany,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              if (location.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: AppColors.faint,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      location,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
            ];
            final identity = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _PersonAvatar(person: person, size: compact ? 64 : 78),
                SizedBox(width: compact ? 14 : 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        person.name,
                        style: peopleEditorialTitle(compact ? 30 : 34),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          for (
                            var i = 0;
                            i < identityMeta.length;
                            i += 1
                          ) ...<Widget>[
                            if (i > 0) const _SmallDot(),
                            identityMeta[i],
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );

            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _ProfileStatement(label: 'Summary', body: person.summary),
                if (person.desires.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  _ProfileStatement(
                    label: 'Looking for',
                    body: person.desires.join(', '),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    for (final tag in person.tags) _TinyChip(tag),
                    _AddTagChip(
                      onTap: () => _addProfileTag(context, ref, person),
                    ),
                  ],
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  _PersonAvatar(person: person, size: 96),
                  const SizedBox(height: 16),
                  Text(
                    person.name,
                    textAlign: TextAlign.center,
                    style: peopleEditorialTitle(30),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (currentTitle.isNotEmpty) currentTitle,
                      if (currentCompany.isNotEmpty) currentCompany,
                    ].join(' at '),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.muted,
                      height: 1.5,
                    ),
                  ),
                  if (person.contacts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _ContactActions(contacts: person.contacts),
                  ],
                  const SizedBox(height: 24),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      identity,
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(left: 96),
                        child: details,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (person.contacts.isNotEmpty)
                      _ContactActions(contacts: person.contacts),
                    if (onEdit != null) ...<Widget>[
                      if (person.contacts.isNotEmpty)
                        const SizedBox(height: 12),
                      TextButton(
                        key: ValueKey('person-edit-button-${person.id}'),
                        onPressed: onEdit,
                        child: const Text('Edit'),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ProfileStatement extends StatelessWidget {
  const _ProfileStatement({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(text: body),
        ],
      ),
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 14,
        height: 1.45,
      ),
    );
  }
}

class _ContactActions extends StatelessWidget {
  const _ContactActions({required this.contacts});

  final List<PersonContact> contacts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final contact in contacts) _ContactIconBox(contact: contact),
      ],
    );
  }
}

class _AddTagChip extends StatelessWidget {
  const _AddTagChip({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.lineStrong),
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.add, size: 14, color: AppColors.faint),
            SizedBox(width: 4),
            Text(
              'Add tag',
              style: TextStyle(
                color: AppColors.faint,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagSelection {
  const _TagSelection({
    required this.system,
    required this.tag,
    this.exclusive = false,
  });

  final String system;
  final String tag;
  final bool exclusive;
}

class _TagPickerSheet extends StatelessWidget {
  const _TagPickerSheet({required this.systems, required this.assignedTags});

  final List<PeopleTagSystem> systems;
  final Map<String, List<String>> assignedTags;

  @override
  Widget build(BuildContext context) {
    final available = [
      for (final system in systems)
        if (system.name != kPeopleStatusTagSystem)
          _TagPickerSystem(
            system: system,
            tags: [
              for (final tag in system.tags)
                if (!_tagIsAssigned(assignedTags, system.name, tag)) tag,
            ],
          ),
    ].where((system) => system.tags.isNotEmpty).toList();

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
                      'Add Tag',
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
            Expanded(
              child: available.isEmpty
                  ? const Center(
                      child: Text(
                        'No available tags.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                      itemBuilder: (context, index) {
                        final system = available[index];
                        return _TagPickerSection(system: system);
                      },
                      separatorBuilder: (_, _) => const SizedBox(height: 22),
                      itemCount: available.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagPickerSystem {
  const _TagPickerSystem({required this.system, required this.tags});

  final PeopleTagSystem system;
  final List<String> tags;
}

class _TagPickerSection extends StatelessWidget {
  const _TagPickerSection({required this.system});

  final _TagPickerSystem system;

  @override
  Widget build(BuildContext context) {
    return _FormSection(
      label: system.system.name,
      icon: system.system.hierarchical
          ? Icons.account_tree_outlined
          : Icons.sell_outlined,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final tag in system.tags)
            ActionChip(
              label: Text(tag),
              onPressed: () => Navigator.of(context).pop(
                _TagSelection(
                  system: system.system.name,
                  tag: tag,
                  exclusive: system.system.exclusive,
                ),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              labelStyle: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              backgroundColor: AppColors.panel,
              side: const BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
        ],
      ),
    );
  }
}

Future<_TagSelection?> _pickTag(
  BuildContext context,
  WidgetRef ref, {
  required Map<String, List<String>> assignedTags,
}) async {
  final systems = await ref.read(peopleTagSystemsProvider.future);
  if (!context.mounted) return null;
  return showModalBottomSheet<_TagSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FractionallySizedBox(
      heightFactor: MediaQuery.sizeOf(context).height < 700 ? 0.95 : 0.75,
      child: _TagPickerSheet(systems: systems, assignedTags: assignedTags),
    ),
  );
}

Future<void> _addProfileTag(
  BuildContext context,
  WidgetRef ref,
  Person person,
) async {
  final current = _copyTagAssignments(person.tagsBySystem);
  final selection = await _pickTag(context, ref, assignedTags: current);
  if (selection == null || !context.mounted) return;
  final next = _assignTag(current, selection);
  final changed = {
    selection.system: next[selection.system] ?? const <String>[],
  };
  try {
    await ref
        .read(peopleRepositoryProvider)
        .updatePersonTags(person.id, changed);
    _invalidatePeopleData(ref, personId: person.id);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not add tag: $error'),
        backgroundColor: AppColors.red,
      ),
    );
  }
}

bool _tagIsAssigned(
  Map<String, List<String>> assignments,
  String system,
  String tag,
) {
  return assignments[system]?.contains(tag) ?? false;
}

Map<String, List<String>> _copyTagAssignments(
  Map<String, List<String>> assignments,
) {
  return {
    for (final entry in assignments.entries)
      entry.key: entry.value.toSet().toList()..sort(),
  };
}

List<_TagSelection> _flattenTagAssignments(
  Map<String, List<String>> assignments,
) {
  return [
    for (final entry in assignments.entries)
      for (final tag in entry.value) _TagSelection(system: entry.key, tag: tag),
  ]..sort((a, b) {
    final systemCompare = a.system.compareTo(b.system);
    if (systemCompare != 0) return systemCompare;
    return a.tag.compareTo(b.tag);
  });
}

Map<String, List<String>> _assignTag(
  Map<String, List<String>> assignments,
  _TagSelection selection,
) {
  final next = _copyTagAssignments(assignments);
  if (selection.exclusive) {
    next[selection.system] = [selection.tag];
    return next;
  }
  final current = next[selection.system] ?? const <String>[];
  next[selection.system] = {...current, selection.tag}.toList()..sort();
  return next;
}

Map<String, List<String>> _removeTagAssignment(
  Map<String, List<String>> assignments,
  _TagSelection selection,
) {
  final next = _copyTagAssignments(assignments);
  final tags = next[selection.system];
  if (tags == null) return next;
  tags.remove(selection.tag);
  if (tags.isEmpty) {
    next.remove(selection.system);
  }
  return next;
}

Map<String, List<String>> _changedTagAssignments(
  Map<String, List<String>> oldAssignments,
  Map<String, List<String>> nextAssignments,
) {
  final oldCopy = _copyTagAssignments(oldAssignments);
  final nextCopy = _copyTagAssignments(nextAssignments);
  final systems = {...oldCopy.keys, ...nextCopy.keys};
  return {
    for (final system in systems)
      if (!_sameStringList(oldCopy[system], nextCopy[system]))
        system: nextCopy[system] ?? const <String>[],
  };
}

bool _sameStringList(List<String>? a, List<String>? b) {
  final left = (a ?? const <String>[]).toSet().toList()..sort();
  final right = (b ?? const <String>[]).toSet().toList()..sort();
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i += 1) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

class _ProfileTabBar extends StatelessWidget {
  const _ProfileTabBar({required this.selected, required this.onSelected});

  final _ProfileDetailTab selected;
  final ValueChanged<_ProfileDetailTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: <Widget>[
          _ProfileTabButton(
            label: 'Meetings',
            selected: selected == _ProfileDetailTab.activity,
            onTap: () => onSelected(_ProfileDetailTab.activity),
          ),
          const SizedBox(width: 22),
          _ProfileTabButton(
            label: 'Background',
            selected: selected == _ProfileDetailTab.background,
            onTap: () => onSelected(_ProfileDetailTab.background),
          ),
        ],
      ),
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  const _ProfileTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.green : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.text : AppColors.faint,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ActivityContent extends StatelessWidget {
  const _ActivityContent({required this.person, required this.desktop});
  final Person person;
  final bool desktop;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (person.actualMeetings.isEmpty)
        const _EmptyPanel(
          title: 'No meetings yet',
          body: 'Your meetings with this person will appear here.',
        ),
      for (final meeting in person.actualMeetings)
        MeetingCard(meeting: meeting),
    ],
  );
}

class _BackgroundContent extends StatelessWidget {
  const _BackgroundContent({required this.person, required this.desktop});

  final Person person;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final experience = _experienceEntries(person);
    final education = _educationEntries(person);
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = desktop && constraints.maxWidth > 760;
        final background = split
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 2,
                    child: _BackgroundListSection(
                      icon: Icons.business_outlined,
                      title: 'Experience',
                      entries: experience,
                      emptyTitle: 'No work relations yet',
                      emptyBody:
                          'Company relations will appear here once they are linked.',
                    ),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        _BackgroundListSection(
                          icon: Icons.school_outlined,
                          title: 'Education',
                          entries: education,
                          emptyTitle: 'No education relations yet',
                          emptyBody:
                              'School or education relations will appear here once they are linked.',
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: <Widget>[
                  _BackgroundListSection(
                    icon: Icons.business_outlined,
                    title: 'Experience',
                    entries: experience,
                    emptyTitle: 'No work relations yet',
                    emptyBody:
                        'Company relations will appear here once they are linked.',
                  ),
                  const SizedBox(height: 24),
                  _BackgroundListSection(
                    icon: Icons.school_outlined,
                    title: 'Education',
                    entries: education,
                    emptyTitle: 'No education relations yet',
                    emptyBody:
                        'School or education relations will appear here once they are linked.',
                  ),
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            background,
            if (!person.suggestions.isEmpty) ...<Widget>[
              const SizedBox(height: 28),
              _SuggestionReviewSection(person: person),
            ],
          ],
        );
      },
    );
  }
}

class _BackgroundListSection extends StatelessWidget {
  const _BackgroundListSection({
    required this.icon,
    required this.title,
    required this.entries,
    required this.emptyTitle,
    required this.emptyBody,
  });

  final IconData icon;
  final String title;
  final List<_BackgroundEntry> entries;
  final String emptyTitle;
  final String emptyBody;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      icon: icon,
      title: title,
      child: entries.isEmpty
          ? _EmptyPanel(title: emptyTitle, body: emptyBody)
          : Column(
              children: <Widget>[
                for (final entry in entries) _BackgroundEntryRow(entry: entry),
              ],
            ),
    );
  }
}

class _BackgroundEntryRow extends StatelessWidget {
  const _BackgroundEntryRow({required this.entry});

  final _BackgroundEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.hover,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(entry.icon, size: 18, color: AppColors.muted),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (entry.subtitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    entry.subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (entry.body.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 7),
                  Text(
                    entry.body,
                    style: const TextStyle(
                      color: AppColors.faint,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundEntry {
  const _BackgroundEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String body;
}

class _SuggestionReviewSection extends ConsumerStatefulWidget {
  const _SuggestionReviewSection({required this.person});

  final Person person;

  @override
  ConsumerState<_SuggestionReviewSection> createState() =>
      _SuggestionReviewSectionState();
}

class _SuggestionReviewSectionState
    extends ConsumerState<_SuggestionReviewSection> {
  String? _busyKey;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final suggestions = widget.person.suggestions;
    final count = suggestions.work.length + suggestions.education.length;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('suggestions-toggle'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.auto_awesome_outlined,
                      size: 16,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: Text(
                        'LINKEDIN SUGGESTIONS',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _TinyChip('$count'),
                    const SizedBox(width: 8),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: AppColors.faint,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  if (suggestions.work.isNotEmpty)
                    _SuggestionGroup(
                      title: 'Work',
                      children: <Widget>[
                        for (
                          var index = 0;
                          index < suggestions.work.length;
                          index++
                        )
                          _SuggestionCard(
                            key: ValueKey('suggestion-work-$index'),
                            kind: PersonSuggestionKind.work,
                            index: index,
                            organization:
                                suggestions.work[index].organizationName,
                            detail: suggestions.work[index].detail,
                            dateRange: _suggestionDateRange(
                              suggestions.work[index].startDate,
                              suggestions.work[index].endDate,
                            ),
                            notes: suggestions.work[index].notes,
                            candidates: suggestions.work[index].candidates,
                            selected: suggestions.work[index].selected,
                            busyKey: _busyKey,
                            onUseCandidate: _useCandidate,
                            onCreateCompany: _createCompany,
                          ),
                      ],
                    ),
                  if (suggestions.work.isNotEmpty &&
                      suggestions.education.isNotEmpty)
                    const SizedBox(height: 14),
                  if (suggestions.education.isNotEmpty)
                    _SuggestionGroup(
                      title: 'Education',
                      children: <Widget>[
                        for (
                          var index = 0;
                          index < suggestions.education.length;
                          index++
                        )
                          _SuggestionCard(
                            key: ValueKey('suggestion-education-$index'),
                            kind: PersonSuggestionKind.education,
                            index: index,
                            organization:
                                suggestions.education[index].organizationName,
                            detail: suggestions.education[index].detail,
                            dateRange: _suggestionDateRange(
                              suggestions.education[index].startDate,
                              suggestions.education[index].endDate,
                            ),
                            notes: suggestions.education[index].notes,
                            candidates: suggestions.education[index].candidates,
                            selected: suggestions.education[index].selected,
                            busyKey: _busyKey,
                            onUseCandidate: _useCandidate,
                            onCreateCompany: _createCompany,
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

  Future<void> _useCandidate(
    PersonSuggestionKind kind,
    int index,
    PersonSuggestionCandidate candidate,
  ) async {
    final key = 'use-${kind.jsonKey}-$index-${candidate.id}';
    await _runSuggestionAction(
      key,
      () => ref
          .read(peopleRepositoryProvider)
          .resolveOrganizationSuggestion(
            personId: widget.person.id,
            kind: kind,
            suggestionIndex: index,
            selected: PersonSuggestionResolution(
              id: candidate.id,
              name: candidate.name,
              source: 'existing',
            ),
          ),
      'Resolved to ${candidate.name}.',
    );
  }

  Future<void> _createCompany(
    PersonSuggestionKind kind,
    int index,
    String name,
  ) async {
    final key = 'create-${kind.jsonKey}-$index';
    await _runSuggestionAction(key, () async {
      await ref
          .read(peopleRepositoryProvider)
          .createCompanyForSuggestion(
            personId: widget.person.id,
            kind: kind,
            suggestionIndex: index,
            name: name,
          );
    }, 'Created $name.');
  }

  Future<void> _runSuggestionAction(
    String key,
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_busyKey != null) return;
    setState(() => _busyKey = key);
    try {
      await action();
      if (!mounted) return;
      _invalidatePeopleData(ref, personId: widget.person.id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suggestion update failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }
}

class _SuggestionGroup extends StatelessWidget {
  const _SuggestionGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionLabel(title),
        const SizedBox(height: 10),
        for (final child in children) ...<Widget>[
          child,
          if (child != children.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    super.key,
    required this.kind,
    required this.index,
    required this.organization,
    required this.detail,
    required this.dateRange,
    required this.notes,
    required this.candidates,
    required this.selected,
    required this.busyKey,
    required this.onUseCandidate,
    required this.onCreateCompany,
  });

  final PersonSuggestionKind kind;
  final int index;
  final String organization;
  final String detail;
  final String dateRange;
  final String notes;
  final List<PersonSuggestionCandidate> candidates;
  final PersonSuggestionResolution? selected;
  final String? busyKey;
  final Future<void> Function(
    PersonSuggestionKind kind,
    int index,
    PersonSuggestionCandidate candidate,
  )
  onUseCandidate;
  final Future<void> Function(PersonSuggestionKind kind, int index, String name)
  onCreateCompany;

  @override
  Widget build(BuildContext context) {
    final resolved = selected?.isValid ?? false;
    final subtitle = [
      detail,
      dateRange,
    ].where((value) => value.trim().isNotEmpty).join(' • ');
    final createKey = 'create-${kind.jsonKey}-$index';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(
          color: resolved
              ? AppColors.green.withValues(alpha: 0.42)
              : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      organization.isEmpty
                          ? 'Unknown organization'
                          : organization,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _TinyChip(kind.label),
            ],
          ),
          if (notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              notes,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (resolved)
            _ResolvedSuggestionChip(selected: selected!)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final maxButtonWidth = constraints.maxWidth < 360
                    ? constraints.maxWidth
                    : 290.0;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final candidate in candidates)
                      _SuggestionActionButton(
                        key: ValueKey(
                          'suggestion-use-${kind.jsonKey}-$index-${candidate.id}',
                        ),
                        icon: Icons.check_circle_outline,
                        label: '${candidate.name} (${candidate.percentage}%)',
                        maxWidth: maxButtonWidth,
                        loading:
                            busyKey ==
                            'use-${kind.jsonKey}-$index-${candidate.id}',
                        onPressed: busyKey == null
                            ? () => onUseCandidate(kind, index, candidate)
                            : null,
                      ),
                    _SuggestionActionButton(
                      key: ValueKey('suggestion-create-${kind.jsonKey}-$index'),
                      icon: Icons.add_business_outlined,
                      label:
                          'Create ${organization.isEmpty ? 'Company' : organization}',
                      maxWidth: maxButtonWidth,
                      loading: busyKey == createKey,
                      onPressed: busyKey == null && organization.isNotEmpty
                          ? () => onCreateCompany(kind, index, organization)
                          : null,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SuggestionActionButton extends StatelessWidget {
  const _SuggestionActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.maxWidth,
    required this.loading,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final double maxWidth;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 17),
      label: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth - 48),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _ResolvedSuggestionChip extends StatelessWidget {
  const _ResolvedSuggestionChip({required this.selected});

  final PersonSuggestionResolution selected;

  @override
  Widget build(BuildContext context) {
    final created = selected.source == 'created';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.resultHover,
        border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: AppColors.green,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              '${created ? 'Created' : 'Resolved to'} ${selected.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogsView extends ConsumerWidget {
  const _LogsView({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offset = ref.watch(
      peopleWorkspaceProvider.select((state) => state.selectedLogDayOffset),
    );
    final now = DateTime.now();
    final day = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: offset));
    final logsValue = ref.watch(dailyLogsForDayProvider(day));
    return Column(
      children: <Widget>[
        _ViewHeader(
          title: 'Logs',
          actionIcon: Icons.add,
          actionKey: const ValueKey('logs-create-button'),
          onActionPressed: () => _showCreateMenu(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Daily notes and images from your people work.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _LogDateNavigator(offset: offset, day: day),
            ],
          ),
        ),
        Expanded(
          child: logsValue.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _EmptyPanel(
              title: 'Could not load logs',
              body: '$error',
              icon: Icons.error_outline,
            ),
            data: (logs) => RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(dailyLogsForDayProvider(day)),
              child: logs.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: const <Widget>[
                        _EmptyPanel(
                          title: 'No logs yet',
                          body:
                              'Use the plus button and choose Log to add text, an image, or both.',
                          icon: Icons.notes_outlined,
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        desktop ? 32 : 18,
                        20,
                        desktop ? 32 : 18,
                        desktop ? 32 : 100,
                      ),
                      itemCount: logs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) =>
                          _LogCard(log: logs[index]),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogDateNavigator extends ConsumerWidget {
  const _LogDateNavigator({required this.offset, required this.day});

  final int offset;
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(peopleWorkspaceProvider.notifier);
    final label = offset == 0
        ? 'Today · ${_month(day.month)} ${day.day}'
        : '${_weekday(day.weekday)} · ${_month(day.month)} ${day.day}, ${day.year}';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.subtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            key: const ValueKey('logs-previous-day-button'),
            tooltip: 'Previous day',
            onPressed: () => notifier.setSelectedLogDayOffset(offset - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: TextButton(
              key: const ValueKey('logs-today-button'),
              onPressed: offset == 0
                  ? null
                  : () => notifier.setSelectedLogDayOffset(0),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('logs-next-day-button'),
            tooltip: 'Next day',
            onPressed: () => notifier.setSelectedLogDayOffset(offset + 1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _LogCard extends ConsumerWidget {
  const _LogCard({required this.log});

  final DailyLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = log.entry?.trim() ?? '';
    final rawImageUrl = log.imageUrl?.trim() ?? '';
    final imageConfig = ref.watch(peopleImageConfigProvider);
    final imageUrl = _resolvePersonImageUrl(rawImageUrl, imageConfig?.baseUrl);
    final headers =
        imageUrl != null &&
            imageConfig != null &&
            _shouldAttachPersonImageHeaders(imageUrl, imageConfig.baseUrl)
        ? imageConfig.headers
        : null;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (imageUrl != null)
            PeopleImage(
              imageUrl,
              headers: headers,
              height: 230,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 120,
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.faint,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _logTimestamp(log.loggedAt),
                  style: const TextStyle(
                    color: AppColors.faint,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (entry.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    entry,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _logTimestamp(DateTime value) {
  String two(int part) => part.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

class _BottomTabs extends ConsumerWidget {
  const _BottomTabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(peopleWorkspaceProvider).section;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              for (var i = 0; i < _navItems.length; i++) ...[
                if (i == 2)
                  const Expanded(child: Center(child: PeopleAssistantButton())),
                Expanded(
                  child: _BottomTabButton(
                    item: _navItems[i],
                    showPending: false,
                    selected: selected == _navItems[i].section,
                    onTap: () => ref
                        .read(peopleWorkspaceProvider.notifier)
                        .setSection(_navItems[i].section),
                  ),
                ),
              ],
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
    this.showPending = false,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool showPending;

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
                  size: 22,
                  color: selected ? AppColors.green : AppColors.muted,
                ),
                const SizedBox(height: 5),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.green : AppColors.muted,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ],
            ),
            if (showPending)
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
  final bool actionFilled = true;
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
              if (actionFilled)
                IconButton.filled(
                  key: actionKey,
                  onPressed: onActionPressed,
                  icon: Icon(actionIcon, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.text,
                    foregroundColor: AppColors.bg,
                  ),
                )
              else
                IconButton(
                  key: actionKey,
                  onPressed: onActionPressed,
                  icon: Icon(actionIcon, size: 20),
                  color: AppColors.text,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: AppColors.text,
                  ),
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

class _CreateMenuSheet extends StatelessWidget {
  const _CreateMenuSheet();

  @override
  Widget build(BuildContext context) {
    return _MenuSheet(
      title: 'Create',
      children: <Widget>[
        _MenuOption(
          key: const ValueKey('create-person-option'),
          icon: Icons.person_add_alt_1_outlined,
          label: 'Person',
          onTap: () => Navigator.of(context).pop(_CreateKind.person),
        ),
        _MenuOption(
          key: const ValueKey('create-meeting-option'),
          icon: Icons.calendar_month_outlined,
          label: 'Meeting',
          onTap: () => Navigator.of(context).pop(_CreateKind.meeting),
        ),
        _MenuOption(
          key: const ValueKey('create-log-option'),
          icon: Icons.note_add_outlined,
          label: 'Log',
          onTap: () => Navigator.of(context).pop(_CreateKind.log),
        ),
      ],
    );
  }
}

class _AppMenuSheet extends ConsumerWidget {
  const _AppMenuSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    return _MenuSheet(
      title: 'Menu',
      children: <Widget>[
        if (user?.domainId != null)
          ListTile(
            title: const Text('Domain'),
            subtitle: Text(user!.domainName ?? 'Domain ${user.domainId}'),
            trailing: TextButton(
              onPressed: () {
                final auth = ref.read(authProvider.notifier);
                Navigator.of(context).pop();
                auth.clearDomain();
              },
              child: const Text('Switch'),
            ),
          ),
        _MenuOption(
          key: const ValueKey('menu-logout-option'),
          icon: Icons.logout,
          label: 'Logout',
          onTap: () => Navigator.of(context).pop(_AppMenuAction.logout),
        ),
      ],
    );
  }
}

class _MenuSheet extends StatelessWidget {
  const _MenuSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuOption extends StatelessWidget {
  const _MenuOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.muted),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.faint),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _MeetingFormSheet extends ConsumerStatefulWidget {
  const _MeetingFormSheet();

  @override
  ConsumerState<_MeetingFormSheet> createState() => _MeetingFormSheetState();
}

class _MeetingFormSheetState extends ConsumerState<_MeetingFormSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  int? _personId;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save(List<Person> people) async {
    final title = _titleController.text.trim();
    final selectedId =
        _personId ??
        ref.read(peopleWorkspaceProvider).activePersonId ??
        people.firstOrNull?.id;
    if (title.isEmpty || selectedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title and choose a person.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(meetingRepositoryProvider)
          .create(
            MeetingDraft(
              title: title,
              description: _descriptionController.text.trim(),
              personId: selectedId,
              startedAt: DateTime.now(),
            ),
          );
      _invalidatePeopleData(ref, personId: selectedId);
      if (mounted) Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint('Meeting creation failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save the meeting: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final peopleValue = ref.watch(recentPeopleProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 18, 22, 24 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Add Meeting',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('meeting-title-field'),
                controller: _titleController,
                enabled: !_saving,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              peopleValue.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Could not load people: $error'),
                data: (people) {
                  final activeId = ref
                      .watch(peopleWorkspaceProvider)
                      .activePersonId;
                  final selectedId =
                      _personId ??
                      (people.any((person) => person.id == activeId)
                          ? activeId
                          : people.firstOrNull?.id);
                  return DropdownButtonFormField<int>(
                    key: const ValueKey('meeting-person-field'),
                    initialValue: selectedId,
                    decoration: const InputDecoration(labelText: 'Person'),
                    items: <DropdownMenuItem<int>>[
                      for (final person in people)
                        DropdownMenuItem<int>(
                          value: person.id,
                          child: Text(person.name),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _personId = value),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('meeting-description-field'),
                controller: _descriptionController,
                enabled: !_saving,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('meeting-save-button'),
                onPressed: _saving ? null : () => peopleValue.whenData(_save),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Save meeting'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogFormSheet extends ConsumerStatefulWidget {
  const _LogFormSheet();

  @override
  ConsumerState<_LogFormSheet> createState() => _LogFormSheetState();
}

class _LogFormSheetState extends ConsumerState<_LogFormSheet> {
  final TextEditingController _entryController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageName;
  bool _saving = false;

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final selected = result.files.single;
    final bytes = selected.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showError('Could not read that image.');
      return;
    }
    setState(() {
      _imageBytes = bytes;
      _imageName = selected.name;
    });
  }

  Future<void> _save() async {
    final entry = _entryController.text.trim();
    if (entry.isEmpty && _imageBytes == null) {
      _showError('Add some text, an image, or both.');
      return;
    }
    final repository = ref.read(logRepositoryProvider);
    setState(() => _saving = true);
    try {
      String? imageUrl;
      final imageBytes = _imageBytes;
      if (imageBytes != null) {
        final uploader = ref.read(logImageUploadServiceProvider);
        if (uploader == null) {
          throw StateError('Image upload is unavailable while signed out.');
        }
        imageUrl = await uploader.upload(
          bytes: imageBytes,
          filename: _imageName ?? 'log-image.jpg',
        );
      }
      await repository.create(
        DailyLogDraft(
          loggedAt: DateTime.now(),
          entry: entry.isEmpty ? null : entry,
          imageUrl: imageUrl,
        ),
      );
      if (!mounted) return;
      ref.invalidate(dailyLogsForDayProvider);
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint('Log creation failed: $error\n$stackTrace');
      if (mounted) _showError('Could not save the log: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 18, 22, 24 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Add Log',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('log-entry-field'),
                controller: _entryController,
                enabled: !_saving,
                minLines: 5,
                maxLines: 10,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'What happened?',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              if (_imageBytes case final bytes?) ...<Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: <Widget>[
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.memory(
                          bytes,
                          key: const ValueKey('log-image-preview'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: IconButton.filled(
                          key: const ValueKey('log-remove-image-button'),
                          onPressed: _saving
                              ? null
                              : () => setState(() {
                                  _imageBytes = null;
                                  _imageName = null;
                                }),
                          tooltip: 'Remove image',
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                OutlinedButton.icon(
                  key: const ValueKey('log-add-image-button'),
                  onPressed: _saving ? null : _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add image'),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: AppColors.lineStrong),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('log-save-button'),
                onPressed: _saving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save log'),
                ),
              ),
            ],
          ),
        ),
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
  late final TextEditingController _summaryController;
  late final TextEditingController _desiresController;
  late final List<_ContactDraftController> _contactControllers;
  late Map<String, List<String>> _tagAssignments;
  bool _saving = false;

  bool get _editing => widget.person != null;

  @override
  void initState() {
    super.initState();
    final person = widget.person;
    _nameController = TextEditingController(text: person?.name ?? '');
    _summaryController = TextEditingController(text: person?.summary ?? '');
    _desiresController = TextEditingController(
      text: person?.desires.join('\n') ?? '',
    );
    _contactControllers = <_ContactDraftController>[
      for (final contact in person?.contacts ?? const <PersonContact>[])
        _ContactDraftController.fromContact(contact),
    ];
    _tagAssignments = _copyTagAssignments(
      person?.tagsBySystem ?? const <String, List<String>>{},
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _summaryController.dispose();
    _desiresController.dispose();
    for (final contact in _contactControllers) {
      contact.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final draft = PersonDraft(
      name: _nameController.text.trim(),
      summary: _summaryController.text.trim(),
      desires: _parseDesiresInput(_desiresController.text),
      contacts: <PersonContact>[
        for (final contact in _contactControllers)
          if (contact.value.text.trim().isNotEmpty) contact.toContact(),
      ],
    );
    final existing = widget.person;
    final tagChanges = _changedTagAssignments(
      existing?.tagsBySystem ?? const <String, List<String>>{},
      _tagAssignments,
    );

    try {
      final repository = ref.read(peopleRepositoryProvider);
      final id = existing == null
          ? await repository.createPerson(draft)
          : existing.id;

      if (existing != null) {
        await repository.updatePerson(existing.id, draft);
      }
      if (tagChanges.isNotEmpty) {
        await repository.updatePersonTags(id, tagChanges);
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

  Future<void> _showAddTagPicker() async {
    final selection = await _pickTag(
      context,
      ref,
      assignedTags: _tagAssignments,
    );
    if (selection == null || !mounted) return;
    _addTag(selection);
  }

  void _addTag(_TagSelection selection) {
    setState(() {
      _tagAssignments = _assignTag(_tagAssignments, selection);
    });
  }

  void _removeTag(_TagSelection selection) {
    setState(() {
      _tagAssignments = _removeTagAssignment(_tagAssignments, selection);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final selectedTags = _flattenTagAssignments(_tagAssignments);
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
                        const SizedBox(height: 18),
                        _ContactEditor(
                          contacts: _contactControllers,
                          enabled: !_saving,
                          onAdd: () => setState(() {
                            _contactControllers.add(_ContactDraftController());
                          }),
                          onRemove: (contact) => setState(() {
                            _contactControllers.remove(contact);
                            contact.dispose();
                          }),
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: 18),
                        _EditableTagsField(
                          selectedTags: selectedTags,
                          onAdd: _saving ? null : _showAddTagPicker,
                          onRemove: _saving ? null : _removeTag,
                        ),
                        const SizedBox(height: 18),
                        _PersonFormField(
                          fieldKey: const ValueKey('person-desires-field'),
                          controller: _desiresController,
                          label: 'Looking for',
                          hint: 'One desire per line',
                          icon: Icons.flag_outlined,
                          minLines: 3,
                          maxLines: 5,
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

class _ContactDraftController {
  _ContactDraftController({
    this.id = 0,
    this.type = 'whatsapp',
    String value = '',
  }) : value = TextEditingController(text: value);

  factory _ContactDraftController.fromContact(PersonContact contact) =>
      _ContactDraftController(
        id: contact.id,
        type: contact.type.trim().isEmpty
            ? 'phone'
            : contact.type.trim().toLowerCase(),
        value: contact.value,
      );

  final int id;
  String type;
  final TextEditingController value;

  PersonContact toContact() =>
      PersonContact(id: id, type: type, value: value.text.trim());
  void dispose() => value.dispose();
}

class _ContactEditor extends StatelessWidget {
  const _ContactEditor({
    required this.contacts,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  final List<_ContactDraftController> contacts;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<_ContactDraftController> onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    const types = <String>['whatsapp', 'wechat', 'linkedin', 'email', 'phone'];
    return _FormSection(
      label: 'Contact identities',
      icon: Icons.alternate_email,
      child: Column(
        children: <Widget>[
          for (final contact in contacts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 118,
                    child: DropdownButtonFormField<String>(
                      initialValue: types.contains(contact.type)
                          ? contact.type
                          : 'phone',
                      items: <DropdownMenuItem<String>>[
                        for (final type in types)
                          DropdownMenuItem(
                            value: type,
                            child: Text(_contactDisplayLabel(type)),
                          ),
                      ],
                      onChanged: enabled
                          ? (value) {
                              if (value != null) contact.type = value;
                              onChanged();
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: contact.value,
                      enabled: enabled,
                      decoration: InputDecoration(
                        hintText: contact.type == 'whatsapp'
                            ? '+8613800138000'
                            : contact.type == 'wechat'
                            ? 'WeChat ID'
                            : 'Identifier',
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (contact.type == 'whatsapp' &&
                            text.isNotEmpty &&
                            !RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(text)) {
                          return 'Use E.164, e.g. +8613800138000';
                        }
                        return null;
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: enabled ? () => onRemove(contact) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: enabled ? onAdd : null,
              icon: const Icon(Icons.add),
              label: const Text('Add contact'),
            ),
          ),
        ],
      ),
    );
  }
}

String _contactDisplayLabel(String type) => switch (type) {
  'whatsapp' => 'WhatsApp',
  'wechat' => 'WeChat',
  'linkedin' => 'LinkedIn',
  'email' => 'Email',
  'phone' => 'Phone',
  _ => 'Contact',
};

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

class _EditableTagsField extends StatelessWidget {
  const _EditableTagsField({
    required this.selectedTags,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_TagSelection> selectedTags;
  final VoidCallback? onAdd;
  final ValueChanged<_TagSelection>? onRemove;

  @override
  Widget build(BuildContext context) {
    return _FormSection(
      label: 'Tags',
      icon: Icons.sell_outlined,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final tag in selectedTags)
            _EditableTagChip(
              tag: tag,
              onDeleted: onRemove == null ? null : () => onRemove!(tag),
            ),
          _AddTagChip(onTap: onAdd),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.label,
    required this.icon,
    required this.child,
  });

  final String label;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 16, color: AppColors.faint),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.faint,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _EditableTagChip extends StatelessWidget {
  const _EditableTagChip({required this.tag, this.onDeleted});

  final _TagSelection tag;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      key: ValueKey('person-tag-chip-${tag.system}-${tag.tag}'),
      label: Text(tag.tag),
      onDeleted: onDeleted,
      deleteIcon: Icon(
        Icons.close,
        key: ValueKey('person-tag-delete-${tag.system}-${tag.tag}'),
        size: 14,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      labelStyle: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: AppColors.subtle,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
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
        color: const Color(0xffe8eae6),
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
      child: PeopleImage(
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
          color: const Color(0xff224a2d),
          fontFamily: size >= 80 ? 'Georgia' : null,
          fontSize: size >= 80 ? 30 : (size < 30 ? 10 : 16),
          fontWeight: FontWeight.w400,
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
    return base?.resolve(trimmed).toString();
  }

  if (base != null && parsed.path.startsWith('/nx_people/profile_files/')) {
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

class _ContactIconBox extends StatelessWidget {
  const _ContactIconBox({required this.contact});

  final PersonContact contact;

  @override
  Widget build(BuildContext context) {
    final target = _contactLaunchUri(contact);
    final isWeChat = _contactType(contact) == 'wechat';
    return IconButton(
      onPressed: target != null
          ? () => launchUrl(target)
          : isWeChat && contact.value.trim().isNotEmpty
          ? () async {
              await Clipboard.setData(
                ClipboardData(text: contact.value.trim()),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('WeChat ID copied.')),
                );
              }
            }
          : null,
      tooltip: _contactTooltip(contact, target),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.subtle,
        disabledBackgroundColor: AppColors.subtle,
        foregroundColor: AppColors.muted,
        disabledForegroundColor: AppColors.faint,
        fixedSize: const Size.square(34),
        minimumSize: const Size.square(34),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: _contactIcon(contact),
    );
  }
}

Widget _contactIcon(PersonContact contact) {
  final type = _contactType(contact);
  if (type == 'email') {
    return const Icon(Icons.mail_outline, size: 17);
  }
  if (type == 'phone') {
    return const Icon(Icons.phone_outlined, size: 17);
  }
  if (type == 'linkedin') {
    return const Text(
      'in',
      style: TextStyle(
        color: Color(0xff0a66c2),
        fontSize: 15,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    );
  }
  if (type == 'whatsapp') {
    return const Icon(Icons.chat_outlined, size: 17, color: Color(0xff25d366));
  }
  if (type == 'wechat') {
    return const Icon(Icons.forum_outlined, size: 17, color: Color(0xff07c160));
  }
  return const Icon(Icons.link_outlined, size: 17);
}

String _contactType(PersonContact contact) => contact.type.trim().toLowerCase();

String _contactTooltip(PersonContact contact, Uri? target) {
  final type = _contactType(contact);
  final label = switch (type) {
    'email' => 'Email',
    'phone' => 'Phone',
    'linkedin' => 'LinkedIn',
    'whatsapp' => 'WhatsApp',
    'wechat' => 'WeChat (tap to copy)',
    _ => 'Contact',
  };
  final value = target?.toString() ?? contact.value.trim();
  if (value.isNotEmpty) return '$label: $value';
  if (contact.name.trim().isNotEmpty) return contact.name.trim();
  return label;
}

Uri? _contactLaunchUri(PersonContact contact) {
  final type = _contactType(contact);
  final value = contact.value.trim();
  final url = contact.url.trim();
  if (type == 'email' && value.isNotEmpty) {
    return Uri(scheme: 'mailto', path: value);
  }
  if (type == 'phone' && value.isNotEmpty) {
    return Uri(scheme: 'tel', path: value);
  }
  if (type == 'whatsapp' && value.isNotEmpty) {
    final number = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (number.isNotEmpty) return Uri.parse('https://wa.me/$number');
  }
  final rawLink = url.isNotEmpty ? url : _derivedContactUrl(type, value);
  if (rawLink == null || rawLink.trim().isEmpty) return null;
  return Uri.tryParse(_ensureUrlScheme(rawLink.trim()));
}

String? _derivedContactUrl(String type, String value) {
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (type == 'linkedin' && value.isNotEmpty) {
    if (value.contains('linkedin.com/')) return value;
    final handle = value.replaceFirst(RegExp(r'^@+'), '').trim();
    if (handle.isEmpty) return null;
    return 'https://www.linkedin.com/in/$handle';
  }
  if ((type == 'link' || type == 'url' || type == 'website') &&
      value.isNotEmpty) {
    return value;
  }
  return null;
}

String _ensureUrlScheme(String value) {
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  return 'https://$value';
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
  });

  final PeopleAppSection section;
  final String label;
  final IconData icon;
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
    section: PeopleAppSection.events,
    label: 'Events',
    icon: Icons.event_outlined,
  ),
  _NavItem(
    section: PeopleAppSection.settings,
    label: 'Settings',
    icon: Icons.settings_outlined,
  ),
];

final _searchPeopleProvider = FutureProvider.family<List<Person>, String>(
  (ref, query) => ref.watch(peopleRepositoryProvider).search(query),
);

enum _ProfileDetailTab { activity, background }

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

String _personListSubtitle(Person person) {
  final company = person.company.trim();
  final role = _profileCurrentTitle(person);
  return [
    if (role.isNotEmpty) role,
    if (company.isNotEmpty) company,
  ].join(' at ');
}

String _profileCurrentTitle(Person person) {
  final company = person.company.trim().toLowerCase();
  PersonBackgroundRelation? matchingRelation;
  for (final relation in person.workRelations) {
    if (company.isEmpty || relation.name.trim().toLowerCase() == company) {
      matchingRelation = relation;
      break;
    }
  }
  final relationTitle = matchingRelation == null
      ? null
      : _backgroundRelationValue(matchingRelation, 'title');
  if (relationTitle != null) return relationTitle;
  return person.role.trim();
}

List<String> _parseDesiresInput(String value) {
  return value
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

List<_BackgroundEntry> _experienceEntries(Person person) {
  return [
    for (final relation in person.workRelations)
      _workBackgroundEntry(person, relation),
  ];
}

List<_BackgroundEntry> _educationEntries(Person person) {
  return [
    for (final relation in person.educationRelations)
      _BackgroundEntry(
        icon: Icons.school_outlined,
        title: relation.name,
        subtitle: _displayEducationType(
          _backgroundRelationValue(relation, 'type') ?? relation.type,
        ),
        body: _backgroundRelationBody(relation),
      ),
  ];
}

String _relationBackedWorkTitle(
  Person person,
  PersonBackgroundRelation relation,
) {
  final relationTitle = _backgroundRelationValue(relation, 'title');
  if (relationTitle != null) return relationTitle;
  final role = person.role.trim();
  final currentCompany = person.company.trim().toLowerCase();
  if (role.isNotEmpty && relation.name.toLowerCase() == currentCompany) {
    return role;
  }
  return relation.name;
}

_BackgroundEntry _workBackgroundEntry(
  Person person,
  PersonBackgroundRelation relation,
) {
  final title = _relationBackedWorkTitle(person, relation);
  return _BackgroundEntry(
    icon: Icons.business_outlined,
    title: title,
    subtitle: title == relation.name ? relation.type : relation.name,
    body: _backgroundRelationBody(relation),
  );
}

String _backgroundRelationBody(PersonBackgroundRelation relation) {
  final description = _normalizeDisplayText(relation.description).trim();
  final dateRange = _suggestionDateRange(
    _backgroundRelationValue(relation, 'start_date') ?? '',
    _backgroundRelationValue(relation, 'end_date'),
  );
  final parts = <String>[
    if (dateRange.isNotEmpty) dateRange,
    if (description.isNotEmpty) description,
    if (_backgroundRelationValue(relation, 'notes') case final notes?) notes,
  ];
  return parts.join('\n');
}

String? _backgroundRelationValue(
  PersonBackgroundRelation relation,
  String key,
) {
  final value = _normalizeDisplayText(
    relation.attributes[key]?.toString() ?? '',
  ).trim();
  return value.isEmpty ? null : value;
}

String _normalizeDisplayText(String value) => value
    .replaceAll(r'\r\n', '\n')
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\r', '\n')
    .replaceAll(r'\"', '"')
    .replaceAll(r'\t', '\t');

String _displayEducationType(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

String _suggestionDateRange(String startDate, String? endDate) {
  final start = _suggestionDateLabel(startDate);
  final end = _suggestionDateLabel(endDate);
  if (start.isEmpty && end.isEmpty) return '';
  if (start.isEmpty) return end;
  if (end.isEmpty) return '$start - Present';
  return '$start - $end';
}

String _suggestionDateLabel(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return '';
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return trimmed;
  return parsed.year.toString();
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

void _selectFirstPersonIfNeeded(WidgetRef ref, List<Person> people) {
  final state = ref.read(peopleWorkspaceProvider);
  if (state.activePersonId != null || people.isEmpty) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(peopleWorkspaceProvider.notifier).openPerson(people.first.id);
  });
}

class _SearchIconPainter extends CustomPainter {
  const _SearchIconPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(8.5, 8.5), 6.5, paint);
    canvas.drawLine(const Offset(13.3, 13.3), const Offset(18, 18), paint);
  }

  @override
  bool shouldRepaint(covariant _SearchIconPainter oldDelegate) => false;
}
