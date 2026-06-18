import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_query.dart';
import 'package:nx_notes/domain/document/document_repository.dart';
import 'package:nx_notes/domain/document/document_snap.dart';
import 'package:nx_notes/domain/links/linked_model.dart';
import 'package:nx_notes/domain/tags/tag_system.dart';

class FakeDocumentRepository implements DocumentRepository {
  FakeDocumentRepository()
    : _documents = _seedDocuments(),
      _snaps = _seedSnaps();

  final List<NxDocument> _documents;
  final Map<int, List<DocumentSnap>> _snaps;
  int _nextDocumentId = 100;
  int _nextSnapId = 1000;
  int _nextRelationId = 5000;

  @override
  Future<NxDocument> create({
    String? title,
    DocumentKind kind = DocumentKind.document,
  }) async {
    final id = _nextDocumentId++;
    final now = DateTime.now();
    final trimmedTitle = title?.trim();
    final documentTitle = trimmedTitle == null || trimmedTitle.isEmpty
        ? 'Untitled document'
        : trimmedTitle;
    final document = NxDocument(
      id: id,
      title: documentTitle,
      modelTypeName: kind.modelTypeName,
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
      excerpt: 'New document draft.',
      links: const <LinkedModel>[],
    );
    _documents.insert(0, document);
    _snaps[id] = <DocumentSnap>[];
    return document;
  }

  @override
  Future<DocumentSnap> createSnapshot(
    int documentId, {
    required String source,
    String changeSummary = '',
  }) async {
    final document = await getById(documentId);
    if (document == null) {
      throw StateError('Document $documentId not found');
    }
    final existing = _snaps[documentId] ?? <DocumentSnap>[];
    final nextVersion = existing.isEmpty
        ? 1
        : existing
                  .map((snap) => snap.versionNumber)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final snap = DocumentSnap(
      id: _nextSnapId++,
      documentId: documentId,
      name: changeSummary.trim().isEmpty ? source : changeSummary.trim(),
      versionNumber: nextVersion,
      document: document.document,
      jsonDocument: document.jsonDocument,
      source: source,
      changeSummary: changeSummary,
      createdAt: DateTime.now(),
    );
    _snaps.putIfAbsent(documentId, () => <DocumentSnap>[]).insert(0, snap);
    return snap;
  }

  @override
  Future<NxDocument?> getById(int id) async {
    for (final document in _documents) {
      if (document.id == id) {
        return document;
      }
    }
    return null;
  }

  @override
  Future<List<NxDocument>> listByTag(DocumentTagFilter filter) async {
    final rows = _documents.where((document) {
      if (filter.system == 'Status') {
        return document.status == filter.node;
      }
      return document.tagsBySystem[filter.system]?.contains(filter.node) ??
          false;
    }).toList();
    rows.sort(_recentSort);
    return rows;
  }

  @override
  Future<List<NxDocument>> listPinned({int limit = 20}) async {
    final rows = _documents.where((document) => document.pinned).toList()
      ..sort(_recentSort);
    return rows.take(limit).toList();
  }

  @override
  Future<List<NxDocument>> listBooks({int limit = 50}) async {
    final rows = _documents.where((document) => document.isBook).toList()
      ..sort(_recentSort);
    return rows.take(limit).toList();
  }

  @override
  Future<List<LinkedModel>> listProjects() async {
    return searchLinkableModels(
      modelType: LinkableModelType.project,
      query: '',
    );
  }

  @override
  Future<List<LinkedModel>> searchLinkableModels({
    required LinkableModelType modelType,
    required String query,
  }) async {
    final normalized = query.trim().toLowerCase();
    return _fakeLinkableModels
        .where((model) => model.modelType == modelType.kgqlName)
        .where(
          (model) =>
              normalized.isEmpty ||
              model.name.toLowerCase().contains(normalized),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<void> attachLinkedModel({
    required int documentId,
    required LinkableModelType modelType,
    required int modelId,
  }) async {
    final document = await getById(documentId);
    if (document == null) {
      throw StateError('Document $documentId not found');
    }
    if (document.links.any(
      (link) => link.modelType == modelType.kgqlName && link.id == modelId,
    )) {
      return;
    }
    final model = _fakeLinkableModels.firstWhere(
      (item) => item.modelType == modelType.kgqlName && item.id == modelId,
      orElse: () => LinkedModel(
        id: modelId,
        name: '${modelType.kgqlName} $modelId',
        modelType: modelType.kgqlName,
      ),
    );
    await updateDraft(
      document.copyWith(
        links: <LinkedModel>[
          ...document.links,
          LinkedModel(
            id: model.id,
            name: model.name,
            modelType: model.modelType,
            relationId: _nextRelationId++,
          ),
        ],
      ),
    );
  }

  @override
  Future<void> attachProject(int documentId, int projectId) async {
    await attachLinkedModel(
      documentId: documentId,
      modelType: LinkableModelType.project,
      modelId: projectId,
    );
  }

  @override
  Future<void> detachProject(int documentId, int relationId) async {
    final document = await getById(documentId);
    if (document == null) {
      throw StateError('Document $documentId not found');
    }
    await updateDraft(
      document.copyWith(
        links: document.links
            .where((link) => link.relationId != relationId)
            .toList(),
      ),
    );
  }

  @override
  Future<List<NxDocument>> listRecent({int limit = 20}) async {
    final rows = [..._documents]..sort(_recentSort);
    return rows.take(limit).toList();
  }

  @override
  Future<List<DocumentSnap>> listSnapshots(int documentId) async {
    return [...?_snaps[documentId]]
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
              count: _documents
                  .where((document) => document.status == name)
                  .length,
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
              count: _documents
                  .where((document) => document.topics.contains(name))
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
            count: _documents
                .where((document) => document.areaTags.contains('Work'))
                .length,
            children: <TagNode>[
              TagNode(
                name: 'Product',
                count: _documents
                    .where((document) => document.areaTags.contains('Product'))
                    .length,
              ),
              TagNode(
                name: 'Infrastructure',
                count: _documents
                    .where(
                      (document) =>
                          document.areaTags.contains('Infrastructure'),
                    )
                    .length,
              ),
            ],
          ),
          TagNode(
            name: 'Personal',
            count: _documents
                .where((document) => document.areaTags.contains('Personal'))
                .length,
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<NxDocument>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return const <NxDocument>[];
    }
    final rows = _documents.where((document) {
      return [
        document.title,
        document.document,
        document.excerpt,
        document.status,
        ...document.tagsBySystem.values.expand((tags) => tags),
      ].join(' ').toLowerCase().contains(q);
    }).toList();
    rows.sort(_recentSort);
    return rows;
  }

  @override
  Future<NxDocument> updateDraft(NxDocument document) async {
    final index = _documents.indexWhere((item) => item.id == document.id);
    if (index == -1) {
      throw StateError('Document ${document.id} not found');
    }
    final updated = document.copyWith(
      updatedAt: DateTime.now(),
      updatedLabel: 'just now',
    );
    _documents[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(int id) async {
    final index = _documents.indexWhere((document) => document.id == id);
    if (index == -1) {
      throw StateError('Document $id not found');
    }
    _documents.removeAt(index);
    _snaps.remove(id);
  }

  static int _recentSort(NxDocument a, NxDocument b) =>
      b.updatedAt.compareTo(a.updatedAt);
}

List<NxDocument> _seedDocuments() {
  final now = DateTime.now();
  NxDocument document({
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
    String modelTypeName = 'Document',
  }) {
    return NxDocument(
      id: id,
      title: title,
      modelTypeName: modelTypeName,
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

  return <NxDocument>[
    document(
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
          'The mobile app should have one document open at a time.\n\nNavigation is stack based: home, tags, or search leads to a result list, then the editor opens from one selected row.',
    ),
    document(
      id: 2,
      title: 'Meditation and the Mind',
      status: 'Published',
      topics: const ['Spiritual'],
      areas: const ['Personal'],
      pinned: false,
      minutesAgo: 120,
      words: 4500,
      version: 24,
      excerpt:
          'A polished document about attention, meditation, and returning.',
      document:
          'Attention is not a possession. It is an activity that has to be returned to again and again.\n\nMeditation makes that return visible.',
    ),
    document(
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
    document(
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
    document(
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
          'The app writes current documents to Document. Meaningful saves create DocumentSnap rows.',
    ),
    document(
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
    document(
      id: 7,
      title: 'KGQL document model',
      status: 'Draft',
      topics: const ['Technical'],
      areas: const ['Work', 'Infrastructure'],
      pinned: true,
      minutesAgo: 3000,
      words: 1370,
      version: 6,
      excerpt:
          'Abstract Document, Document, and DocumentSnap model type notes.',
      document:
          'Abstract Document owns document and json_document. Document is the canonical live document.',
    ),
    document(
      id: 8,
      title: 'Writing system principles',
      status: 'Published',
      topics: const ['Personal'],
      areas: const ['Personal'],
      pinned: true,
      minutesAgo: 7000,
      words: 1650,
      version: 15,
      excerpt: 'How internal documents connect to actions, nouns, and context.',
      document:
          'A good writing system makes capture easy, retrieval precise, and revision low friction.',
    ),
  ];
}

Map<int, List<DocumentSnap>> _seedSnaps() {
  return <int, List<DocumentSnap>>{
    for (final document in _seedDocuments())
      document.id: <DocumentSnap>[
        DocumentSnap(
          id: document.id * 10,
          documentId: document.id,
          name: 'Latest checkpoint',
          versionNumber: document.versionNumber,
          document: document.document,
          jsonDocument: document.jsonDocument,
          source: 'manual',
          changeSummary: 'Latest checkpoint',
          createdAt: document.updatedAt,
        ),
      ],
  };
}

const List<LinkedModel> _fakeLinkableModels = <LinkedModel>[
  LinkedModel(id: 54, name: 'Notes App', modelType: 'Project'),
  LinkedModel(id: 55, name: 'KGQL Platform', modelType: 'Project'),
  LinkedModel(id: 56, name: 'Internal Tools', modelType: 'Project'),
  LinkedModel(id: 57, name: 'Writing System', modelType: 'Project'),
  LinkedModel(id: 201, name: 'Nathik Azad', modelType: 'Person'),
  LinkedModel(id: 202, name: 'Sarah Chen', modelType: 'Person'),
  LinkedModel(id: 203, name: 'Alex Morgan', modelType: 'Person'),
  LinkedModel(id: 301, name: 'Nexus Labs', modelType: 'Company'),
  LinkedModel(id: 302, name: 'OpenAI', modelType: 'Company'),
  LinkedModel(id: 303, name: 'Apple', modelType: 'Company'),
  LinkedModel(id: 1, name: 'Draft: API design notes', modelType: 'Document'),
  LinkedModel(
    id: 4,
    name: 'Internal notes app direction',
    modelType: 'Document',
  ),
  LinkedModel(id: 7, name: 'KGQL document model', modelType: 'Document'),
];
