import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_people/core/theme/app_theme.dart';
import 'package:nx_people/data/fake_people_repository.dart';
import 'package:nx_people/domain/person/person.dart';
import 'package:nx_people/domain/person/person_query.dart';
import 'package:nx_people/features/shell/people_state.dart';

class MobileShell extends ConsumerWidget {
  const MobileShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(peopleWorkspaceProvider);
    final repository = ref.watch(peopleRepositoryProvider);
    final person = repository.byId(workspace.activePersonId);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: workspace.activeContext == null
              ? null
              : () => ref
                    .read(peopleWorkspaceProvider.notifier)
                    .returnToActiveContext(),
          icon: const Icon(Icons.chevron_left),
        ),
        title: Text(person.name, style: const TextStyle(fontSize: 14)),
        actions: <Widget>[
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
        ],
      ),
      body: Stack(
        children: <Widget>[
          _MobileProfile(person: person),
          if (workspace.hasOverlay)
            _MobileResultOverlay(contextModel: workspace.overlayContext!),
        ],
      ),
      bottomNavigationBar: const _MobileTabs(),
    );
  }
}

class _MobileProfile extends StatelessWidget {
  const _MobileProfile({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 130),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Avatar(initials: person.initials),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    person.name,
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${person.role} · ${person.company} · ${person.location}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      _Pill(person.status),
                      for (final tag in person.tags) _Pill(tag),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _Section(title: 'Summary', child: Text(person.summary)),
        _Section(
          title: 'Current Threads',
          child: Column(
            children: <Widget>[
              for (final thread in person.currentThreads)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(thread.title),
                  subtitle: Text(thread.body),
                ),
            ],
          ),
        ),
        _Section(
          title: 'Recent Activity',
          child: Column(
            children: <Widget>[
              for (final log in person.logs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: SizedBox(width: 52, child: Text(log.time)),
                  title: const Text('Daily log'),
                  subtitle: Text(log.body),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileResultOverlay extends ConsumerWidget {
  const _MobileResultOverlay({required this.contextModel});

  final PeopleResultContext contextModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(peopleRepositoryProvider);
    final rows = repository.peopleFor(contextModel);
    return Material(
      color: Colors.white.withValues(alpha: 0.97),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 36),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  contextModel.title,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: () =>
                    ref.read(peopleWorkspaceProvider.notifier).hideOverlay(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            '${rows.length} people',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Text(
            'Pick a person to open their profile. The profile keeps this list as a back context.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          for (final person in rows)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: _Avatar(initials: person.initials, small: true),
              title: Text(person.name),
              subtitle: Text('${person.role} · ${person.company} · ${person.location}'),
              onTap: () => ref
                  .read(peopleWorkspaceProvider.notifier)
                  .openPerson(person.id, context: contextModel),
            ),
        ],
      ),
    );
  }
}

class _MobileTabs extends ConsumerWidget {
  const _MobileTabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mobile = ref.watch(mobilePeopleProvider);
    final repository = ref.read(peopleRepositoryProvider);
    return NavigationBar(
      selectedIndex: mobile.section.index,
      onDestinationSelected: (index) {
        final section = MobilePeopleSection.values[index];
        ref.read(mobilePeopleProvider.notifier).setSection(section);
        switch (section) {
          case MobilePeopleSection.people:
            ref
                .read(peopleWorkspaceProvider.notifier)
                .showOverlay(PeopleResultContext(
                  type: 'Recent',
                  label: 'People',
                  personIds: repository.people.map((person) => person.id).toList(),
                ));
          case MobilePeopleSection.tags:
            ref
                .read(peopleWorkspaceProvider.notifier)
                .showOverlay(repository.context('Status', 'Follow up'));
          case MobilePeopleSection.search:
            ref
                .read(peopleWorkspaceProvider.notifier)
                .showOverlay(repository.context('Search', mobile.searchText));
        }
      },
      destinations: const <NavigationDestination>[
        NavigationDestination(icon: Icon(Icons.view_list), label: 'People'),
        NavigationDestination(icon: Icon(Icons.sell_outlined), label: 'Tags'),
        NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
      ],
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
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          DefaultTextStyle.merge(
            style: const TextStyle(
              color: Color(0xff3f3f46),
              fontSize: 15,
              height: 1.65,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.subtle,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, this.small = false});

  final String initials;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 34.0 : 46.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.subtle,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(small ? 8 : 10),
      ),
      child: Text(
        initials,
        style: TextStyle(fontSize: small ? 12 : 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
