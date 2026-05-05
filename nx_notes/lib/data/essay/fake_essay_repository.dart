import 'package:nx_notes/domain/essay/essay.dart';
import 'package:nx_notes/domain/essay/essay_query.dart';
import 'package:nx_notes/domain/essay/essay_repository.dart';
import 'package:nx_notes/domain/essay/essay_snap.dart';
import 'package:nx_notes/domain/links/linked_model.dart';
import 'package:nx_notes/domain/tags/tag_system.dart';

class FakeEssayRepository implements EssayRepository {
  FakeEssayRepository() : _essays = _seedEssays(), _snaps = _seedSnaps();

  final List<Essay> _essays;
  final Map<int, List<EssaySnap>> _snaps;
  int _nextEssayId = 100;
  int _nextSnapId = 1000;

  @override
  Future<Essay> create() async {
    final id = _nextEssayId++;
    final now = DateTime.now();
    final essay = Essay(
      id: id,
      title: 'Untitled essay',
      document: 'Start writing here.',
      jsonDocument: const <String, dynamic>{
        'format': 'appflowy_document',
        'document': <String, dynamic>{
          'type': 'page',
          'children': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'paragraph',
              'data': <String, dynamic>{
                'delta': <Map<String, dynamic>>[
                  <String, dynamic>{'insert': 'Start writing here.'},
                ],
              },
            },
          ],
        },
      },
      wordCount: 3,
      status: 'Draft',
      topics: const <String>[],
      areaTags: const <String>[],
      tagsBySystem: const <String, List<String>>{
        'Status': <String>['Draft'],
        'Topic': <String>[],
        'Area': <String>[],
      },
      pinned: false,
      updatedAt: now,
      updatedLabel: 'just now',
      versionNumber: 1,
      excerpt: 'New essay draft.',
      links: const <LinkedModel>[],
    );
    _essays.insert(0, essay);
    _snaps[id] = <EssaySnap>[];
    return essay;
  }

  @override
  Future<EssaySnap> createSnapshot(
    int essayId, {
    required String source,
    String changeSummary = '',
  }) async {
    final essay = await getById(essayId);
    if (essay == null) {
      throw StateError('Essay $essayId not found');
    }
    final existing = _snaps[essayId] ?? <EssaySnap>[];
    final nextVersion = existing.isEmpty
        ? 1
        : existing
                  .map((snap) => snap.versionNumber)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final snap = EssaySnap(
      id: _nextSnapId++,
      essayId: essayId,
      versionNumber: nextVersion,
      document: essay.document,
      jsonDocument: essay.jsonDocument,
      source: source,
      changeSummary: changeSummary,
      createdAt: DateTime.now(),
    );
    _snaps.putIfAbsent(essayId, () => <EssaySnap>[]).insert(0, snap);
    return snap;
  }

  @override
  Future<Essay?> getById(int id) async {
    for (final essay in _essays) {
      if (essay.id == id) {
        return essay;
      }
    }
    return null;
  }

  @override
  Future<List<Essay>> listByTag(EssayTagFilter filter) async {
    final rows = _essays.where((essay) {
      if (filter.system == 'Status') {
        return essay.status == filter.node;
      }
      return essay.tagsBySystem[filter.system]?.contains(filter.node) ?? false;
    }).toList();
    rows.sort(_recentSort);
    return rows;
  }

  @override
  Future<List<Essay>> listPinned({int limit = 20}) async {
    final rows = _essays.where((essay) => essay.pinned).toList()
      ..sort(_recentSort);
    return rows.take(limit).toList();
  }

  @override
  Future<List<Essay>> listRecent({int limit = 20}) async {
    final rows = [..._essays]..sort(_recentSort);
    return rows.take(limit).toList();
  }

  @override
  Future<List<EssaySnap>> listSnapshots(int essayId) async {
    return [...?_snaps[essayId]]
      ..sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
  }

  @override
  Future<List<TagSystem>> listTagSystems() async {
    return <TagSystem>[
      TagSystem(
        name: 'Status',
        exclusive: true,
        nodes: <TagNode>[
          for (final name in const [
            'Draft',
            'In Progress',
            'Published',
            'Discarded',
          ])
            TagNode(
              name: name,
              count: _essays.where((essay) => essay.status == name).length,
            ),
        ],
      ),
      TagSystem(
        name: 'Topic',
        nodes: <TagNode>[
          for (final name in const [
            'Technical',
            'Product',
            'Spiritual',
            'Economic',
            'Personal',
          ])
            TagNode(
              name: name,
              count: _essays
                  .where((essay) => essay.topics.contains(name))
                  .length,
            ),
        ],
      ),
      TagSystem(
        name: 'Area',
        hierarchical: true,
        nodes: <TagNode>[
          TagNode(
            name: 'Work',
            count: _essays
                .where((essay) => essay.areaTags.contains('Work'))
                .length,
            children: <TagNode>[
              TagNode(
                name: 'Product',
                count: _essays
                    .where((essay) => essay.areaTags.contains('Product'))
                    .length,
              ),
              TagNode(
                name: 'Infrastructure',
                count: _essays
                    .where((essay) => essay.areaTags.contains('Infrastructure'))
                    .length,
              ),
            ],
          ),
          TagNode(
            name: 'Personal',
            count: _essays
                .where((essay) => essay.areaTags.contains('Personal'))
                .length,
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<Essay>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return const <Essay>[];
    }
    final rows = _essays.where((essay) {
      return [
        essay.title,
        essay.document,
        essay.excerpt,
        essay.status,
        ...essay.tagsBySystem.values.expand((tags) => tags),
      ].join(' ').toLowerCase().contains(q);
    }).toList();
    rows.sort(_recentSort);
    return rows;
  }

  @override
  Future<Essay> updateDraft(Essay essay) async {
    final index = _essays.indexWhere((item) => item.id == essay.id);
    if (index == -1) {
      throw StateError('Essay ${essay.id} not found');
    }
    final updated = essay.copyWith(
      updatedAt: DateTime.now(),
      updatedLabel: 'just now',
    );
    _essays[index] = updated;
    return updated;
  }

  static int _recentSort(Essay a, Essay b) =>
      b.updatedAt.compareTo(a.updatedAt);
}

List<Essay> _seedEssays() {
  final now = DateTime.now();
  Essay essay({
    required int id,
    required String title,
    required String status,
    required List<String> topics,
    required List<String> areas,
    required bool pinned,
    required int minutesAgo,
    required int words,
    required int version,
    required String excerpt,
    required String document,
  }) {
    return Essay(
      id: id,
      title: title,
      document: document,
      jsonDocument: <String, dynamic>{'plainText': document},
      wordCount: words,
      status: status,
      topics: topics,
      areaTags: areas,
      tagsBySystem: <String, List<String>>{
        'Status': <String>[status],
        'Topic': topics,
        'Area': areas,
      },
      pinned: pinned,
      updatedAt: now.subtract(Duration(minutes: minutesAgo)),
      updatedLabel: minutesAgo < 60
          ? '${minutesAgo}m ago'
          : '${(minutesAgo / 60).round()}h ago',
      versionNumber: version,
      excerpt: excerpt,
      links: const <LinkedModel>[
        LinkedModel(id: 1, name: 'Implement note editor', modelType: 'Action'),
      ],
    );
  }

  return <Essay>[
    essay(
      id: 1,
      title: 'Draft: API design notes',
      status: 'Draft',
      topics: const ['Technical'],
      areas: const ['Work', 'Infrastructure'],
      pinned: false,
      minutesAgo: 12,
      words: 842,
      version: 18,
      excerpt: 'Notes on KGQL, AppFlowy JSON, raw text, tags, and snapshots.',
      document:
          'The mobile app should have one essay open at a time.\n\nNavigation is stack based: home, tags, or search leads to a result list, then the editor opens from one selected row.',
    ),
    essay(
      id: 2,
      title: 'Meditation and the Mind',
      status: 'Published',
      topics: const ['Spiritual'],
      areas: const ['Personal'],
      pinned: false,
      minutesAgo: 120,
      words: 4500,
      version: 24,
      excerpt: 'A polished essay about attention, meditation, and returning.',
      document:
          'Attention is not a possession. It is an activity that has to be returned to again and again.\n\nMeditation makes that return visible.',
    ),
    essay(
      id: 3,
      title: 'The Economics of Meditation',
      status: 'In Progress',
      topics: const ['Spiritual', 'Economic'],
      areas: const ['Personal'],
      pinned: false,
      minutesAgo: 180,
      words: 3200,
      version: 13,
      excerpt: 'Meditation as an attention budget with costs and returns.',
      document:
          'A day has a budget of attention. The question is whether that budget is spent by intention or auctioned away by default.',
    ),
    essay(
      id: 4,
      title: 'Internal notes app direction',
      status: 'Draft',
      topics: const ['Product'],
      areas: const ['Work', 'Product'],
      pinned: false,
      minutesAgo: 240,
      words: 1190,
      version: 7,
      excerpt: 'Product notes for an internal Notion-like KGQL app.',
      document:
          'The app should open directly into work. Navigation is secondary to writing and retrieval.',
    ),
    essay(
      id: 5,
      title: 'KGQL API shape for notes',
      status: 'In Progress',
      topics: const ['Technical'],
      areas: const ['Work', 'Infrastructure'],
      pinned: false,
      minutesAgo: 1440,
      words: 980,
      version: 9,
      excerpt: 'set_kgql_models calls, relation links, and query structs.',
      document:
          'The app writes current documents to Essay. Meaningful saves create EssaySnap rows.',
    ),
    essay(
      id: 6,
      title: 'Notes product spec',
      status: 'In Progress',
      topics: const ['Product'],
      areas: const ['Work', 'Product'],
      pinned: true,
      minutesAgo: 2880,
      words: 2100,
      version: 11,
      excerpt: 'The working product spec for notes navigation and editing.',
      document:
          'Desktop is a workspace. Mobile is a stack. Both share the same repository and document model.',
    ),
    essay(
      id: 7,
      title: 'KGQL document model',
      status: 'Draft',
      topics: const ['Technical'],
      areas: const ['Work', 'Infrastructure'],
      pinned: true,
      minutesAgo: 3000,
      words: 1370,
      version: 6,
      excerpt: 'Abstract Essay, Essay, and EssaySnap model type notes.',
      document:
          'Abstract Essay owns document and json_document. Essay is the canonical live document.',
    ),
    essay(
      id: 8,
      title: 'Writing system principles',
      status: 'Published',
      topics: const ['Personal'],
      areas: const ['Personal'],
      pinned: true,
      minutesAgo: 7000,
      words: 1650,
      version: 15,
      excerpt: 'How internal essays connect to actions, nouns, and context.',
      document:
          'A good writing system makes capture easy, retrieval precise, and revision low friction.',
    ),
  ];
}

Map<int, List<EssaySnap>> _seedSnaps() {
  return <int, List<EssaySnap>>{
    for (final essay in _seedEssays())
      essay.id: <EssaySnap>[
        EssaySnap(
          id: essay.id * 10,
          essayId: essay.id,
          versionNumber: essay.versionNumber,
          document: essay.document,
          jsonDocument: essay.jsonDocument,
          source: 'manual',
          changeSummary: 'Latest checkpoint',
          createdAt: essay.updatedAt,
        ),
      ],
  };
}
