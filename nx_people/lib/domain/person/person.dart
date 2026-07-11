class Person {
  const Person({
    required this.id,
    required this.name,
    required this.initials,
    required this.company,
    required this.role,
    required this.location,
    required this.status,
    required this.statusColor,
    required this.lastContact,
    required this.updatedAt,
    required this.nextFollowUp,
    required this.pinned,
    required this.email,
    required this.phone,
    required this.tags,
    required this.meetings,
    required this.planned,
    required this.summary,
    required this.currentThreads,
    required this.logs,
    required this.relatedIds,
    this.imageUrl = '',
  });

  final int id;
  final String name;
  final String initials;
  final String company;
  final String role;
  final String location;
  final String status;
  final PersonStatusColor statusColor;
  final String lastContact;
  final String updatedAt;
  final String nextFollowUp;
  final bool pinned;
  final String email;
  final String phone;
  final List<String> tags;
  final List<String> meetings;
  final List<String> planned;
  final String summary;
  final List<PersonThread> currentThreads;
  final List<PersonLog> logs;
  final List<int> relatedIds;
  final String imageUrl;

  bool matches(String query) {
    final normalized = query.toLowerCase();
    return <String>[
      name,
      company,
      role,
      location,
      status,
      summary,
      email,
      phone,
      ...tags,
    ].join(' ').toLowerCase().contains(normalized);
  }
}

class PersonThread {
  const PersonThread({required this.title, required this.body});

  final String title;
  final String body;
}

class PersonLog {
  const PersonLog({required this.time, required this.body});

  final String time;
  final String body;
}

enum PersonStatusColor { green, blue, amber, red }
