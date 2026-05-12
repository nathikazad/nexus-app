import 'package:nx_people/domain/person/person.dart';
import 'package:nx_people/domain/person/person_query.dart';

const companies = <String>[
  'Northstar Labs',
  'Atlas Capital',
  'Quiet Systems',
  'Nexus',
];

const meetings = <String>[
  'Design Sync',
  'Investor Intro',
  'Weekly Planning',
  'Q1 Portfolio Review',
];

const planned = <String>['Roadmap Review', 'Q2 Check-in'];

const fakeTagSystems = <PeopleTagSystem>[
  PeopleTagSystem(
    name: 'Status',
    tags: <String>['Active', 'Follow up', 'Dormant'],
  ),
  PeopleTagSystem(
    name: 'Relationship',
    tags: <String>['Investor', 'Advisor', 'Founder', 'Warm', 'Personal'],
  ),
  PeopleTagSystem(
    name: 'Context',
    tags: <String>['Product', 'Finance', 'Design', 'Remote'],
  ),
  PeopleTagSystem(
    name: 'Location',
    tags: <String>['SF', 'Tbilisi', 'New York'],
  ),
];

class FakePeopleRepository implements PersonRepository {
  const FakePeopleRepository([this.people = _people]);

  final List<Person> people;

  Person _byId(int id) => people.firstWhere((person) => person.id == id);

  @override
  Future<Person?> getById(int id) async {
    for (final person in people) {
      if (person.id == id) return person;
    }
    return null;
  }

  @override
  Future<List<Person>> listPinned({int limit = 20}) async {
    return people.where((person) => person.pinned).take(limit).toList();
  }

  @override
  Future<List<Person>> listRecent({int limit = 20}) async {
    return <Person>[
      _byId(4),
      _byId(1),
      _byId(2),
      _byId(6),
      _byId(3),
    ].take(limit).toList();
  }

  @override
  Future<List<Person>> listFollowUp({int limit = 20}) async {
    return people
        .where((person) => person.status == 'Follow up')
        .take(limit)
        .toList();
  }

  @override
  Future<List<Person>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const <Person>[];
    return people.where((person) => person.matches(trimmed)).toList();
  }

  @override
  Future<PeopleResultContext> context(String type, String label) async {
    final rows = await _filter(type, label);
    return PeopleResultContext(
      type: type,
      label: label,
      personIds: rows.map((person) => person.id).toList(),
    );
  }

  @override
  Future<List<Person>> peopleFor(PeopleResultContext context) async {
    return [
      for (final id in context.personIds)
        if (await getById(id) case final person?) person,
    ];
  }

  @override
  Future<int> count(String type, String label) async {
    return (await _filter(type, label)).length;
  }

  @override
  Future<List<String>> listCompanies() async => companies;

  @override
  Future<List<String>> listMeetings() async => meetings;

  @override
  Future<List<String>> listPlanned() async => planned;

  @override
  Future<List<PeopleTagSystem>> listTagSystems() async => fakeTagSystems;

  Future<List<Person>> _filter(String type, String label) async {
    return switch (type) {
      'Search' => search(label),
      'Recent' => Future<List<Person>>.value(people),
      'Company' => Future<List<Person>>.value(
        people.where((person) => person.company == label).toList(),
      ),
      'Meeting' => Future<List<Person>>.value(
        people.where((person) => person.meetings.contains(label)).toList(),
      ),
      'Planned' => Future<List<Person>>.value(
        people.where((person) => person.planned.contains(label)).toList(),
      ),
      'Status' => Future<List<Person>>.value(
        people.where((person) => person.status == label).toList(),
      ),
      _ => Future<List<Person>>.value(
        people.where((person) => person.tags.contains(label)).toList(),
      ),
    };
  }
}

const _people = <Person>[
  Person(
    id: 1,
    name: 'Sarah Chen',
    initials: 'SC',
    company: 'Northstar Labs',
    role: 'Product Lead',
    location: 'San Francisco',
    status: 'Follow up',
    statusColor: PersonStatusColor.amber,
    lastContact: '3d ago',
    nextFollowUp: 'Tomorrow',
    pinned: true,
    email: 'sarah@northstar.example',
    phone: '+1 415 555 0182',
    tags: <String>['Product', 'Investor', 'SF', 'Warm'],
    meetings: <String>['Design Sync', 'Investor Intro'],
    planned: <String>['Roadmap Review'],
    summary:
        'Sarah is a product operator with strong taste around internal tools. She is useful for pressure-testing whether a workflow is actually clear or just visually polished.',
    currentThreads: <PersonThread>[
      PersonThread(
        title: 'Send notes prototype',
        body:
            'Promised to share the notes UI once the back-navigation flow is tightened.',
      ),
      PersonThread(
        title: 'Ask about hiring graph',
        body:
            'She mentioned a hiring CRM problem that maps closely to KGQL people relations.',
      ),
    ],
    logs: <PersonLog>[
      PersonLog(
        time: 'Today',
        body:
            'Added her to the Product relationship group and marked follow-up for tomorrow.',
      ),
      PersonLog(
        time: '3d ago',
        body:
            'Met during Design Sync. She liked recoverable result navigation.',
      ),
      PersonLog(
        time: 'Oct 22',
        body:
            'Intro from Maya. Strong interest in tools for personal operating systems.',
      ),
    ],
    relatedIds: <int>[2, 4],
  ),
  Person(
    id: 2,
    name: 'Marcus Rivera',
    initials: 'MR',
    company: 'Atlas Capital',
    role: 'Partner',
    location: 'New York',
    status: 'Active',
    statusColor: PersonStatusColor.green,
    lastContact: 'Yesterday',
    nextFollowUp: 'Friday',
    pinned: true,
    email: 'marcus@atlas.example',
    phone: '+1 212 555 0134',
    tags: <String>['Investor', 'Finance', 'Warm'],
    meetings: <String>['Investor Intro'],
    planned: <String>['Q2 Check-in'],
    summary:
        'Marcus is focused on founder systems, metrics, and capital allocation. Good person for finance-oriented product framing.',
    currentThreads: <PersonThread>[
      PersonThread(
        title: 'Deck follow-up',
        body: 'Send short write-up on KGQL as a personal graph database.',
      ),
    ],
    logs: <PersonLog>[
      PersonLog(
        time: 'Yesterday',
        body:
            'Quick call. He asked for a tighter example around people, companies, and meetings.',
      ),
      PersonLog(time: 'Apr 29', body: 'Introduced by Sarah Chen.'),
    ],
    relatedIds: <int>[1, 5],
  ),
  Person(
    id: 3,
    name: 'Anika Patel',
    initials: 'AP',
    company: 'Quiet Systems',
    role: 'Founder',
    location: 'London',
    status: 'Active',
    statusColor: PersonStatusColor.green,
    lastContact: '1w ago',
    nextFollowUp: 'None',
    pinned: false,
    email: 'anika@quiet.example',
    phone: '+44 20 5555 0191',
    tags: <String>['Founder', 'Product', 'Remote'],
    meetings: <String>['Design Sync'],
    planned: <String>[],
    summary:
        'Anika builds calm operational software. She tends to care about density, keyboard flow, and avoiding dashboard theater.',
    currentThreads: <PersonThread>[
      PersonThread(
        title: 'Ask about mobile CRM',
        body: 'She has opinions about single-profile mobile navigation.',
      ),
    ],
    logs: <PersonLog>[
      PersonLog(
        time: '1w ago',
        body:
            'Discussed whether People should be a profile/timeline instead of an address book.',
      ),
    ],
    relatedIds: <int>[1],
  ),
  Person(
    id: 4,
    name: 'Maya Ioseliani',
    initials: 'MI',
    company: 'Nexus',
    role: 'Advisor',
    location: 'Tbilisi',
    status: 'Active',
    statusColor: PersonStatusColor.green,
    lastContact: 'Today',
    nextFollowUp: 'Today',
    pinned: true,
    email: 'maya@nexus.example',
    phone: '+995 555 012 345',
    tags: <String>['Advisor', 'Tbilisi', 'Warm', 'Personal'],
    meetings: <String>['Weekly Planning', 'Investor Intro'],
    planned: <String>['Roadmap Review'],
    summary:
        'Maya connects product strategy with day-to-day execution. Usually the best person to ask whether a workflow will survive real use.',
    currentThreads: <PersonThread>[
      PersonThread(
        title: 'Review people mockup',
        body: 'Ask if the company and meeting navigation feels natural.',
      ),
    ],
    logs: <PersonLog>[
      PersonLog(
        time: 'Today',
        body:
            'Asked for a People app mockup based on the notes navigation pattern.',
      ),
      PersonLog(
        time: '2d ago',
        body: 'Talked through tags and recoverable result contexts.',
      ),
    ],
    relatedIds: <int>[1, 2],
  ),
  Person(
    id: 5,
    name: 'Daniel Brooks',
    initials: 'DB',
    company: 'Atlas Capital',
    role: 'Analyst',
    location: 'New York',
    status: 'Dormant',
    statusColor: PersonStatusColor.blue,
    lastContact: '2mo ago',
    nextFollowUp: 'None',
    pinned: false,
    email: 'daniel@atlas.example',
    phone: '+1 646 555 0147',
    tags: <String>['Finance', 'Dormant'],
    meetings: <String>['Q1 Portfolio Review'],
    planned: <String>[],
    summary:
        'Daniel tracks portfolio tooling and research workflows. Not urgent, but useful for later finance product interviews.',
    currentThreads: <PersonThread>[
      PersonThread(
        title: 'No current thread',
        body: 'Keep dormant until there is a finance-specific prototype.',
      ),
    ],
    logs: <PersonLog>[
      PersonLog(time: '2mo ago', body: 'Brief intro during portfolio review.'),
    ],
    relatedIds: <int>[2],
  ),
  Person(
    id: 6,
    name: 'Elena Torres',
    initials: 'ET',
    company: 'Northstar Labs',
    role: 'Design Engineer',
    location: 'Austin',
    status: 'Follow up',
    statusColor: PersonStatusColor.amber,
    lastContact: '5d ago',
    nextFollowUp: 'Monday',
    pinned: false,
    email: 'elena@northstar.example',
    phone: '+1 512 555 0156',
    tags: <String>['Design', 'Product', 'Remote'],
    meetings: <String>['Design Sync'],
    planned: <String>['Roadmap Review'],
    summary:
        'Elena is detail-oriented about interaction states, overlays, and mobile adaptation.',
    currentThreads: <PersonThread>[
      PersonThread(
        title: 'Overlay question',
        body:
            'Ask whether people result rows need richer relationship metadata.',
      ),
    ],
    logs: <PersonLog>[
      PersonLog(
        time: '5d ago',
        body:
            'She pushed for a full-width overlay rather than a centered modal.',
      ),
    ],
    relatedIds: <int>[1, 3],
  ),
];
