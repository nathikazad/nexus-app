import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_books/domain/book/book.dart';
import 'package:nx_books/domain/book/book_repository.dart';
import 'package:nx_db/kgql.dart';

const kBookModelTypeName = 'Book';
const kBookAttrReadingState = 'reading_state';
const kBookAttrRank = 'rank';
const kBookAttrTotalChapters = 'total_chapters';
const kBookAttrCurrentChapter = 'current_chapter';
const kBookAttrWordCount = 'word_count';
const kBookAttrDocument = 'document';
const kBookAttrJsonDocument = 'json_document';
const kBookAttrPinned = 'pinned';
const kBookAttrShareToWeb = 'share_to_web';
const kBookTopicTagSystem = 'Topic';

class KgqlBookRepository implements BookRepository {
  KgqlBookRepository({required GraphQLClient client}) : _client = client;

  final GraphQLClient _client;

  @override
  Future<List<NxBook>> listBooks() async {
    final models = await fetchKgqlModels(
      _client,
      filter: const {'model_type': kBookModelTypeName},
      struct: bookSummaryFetchStruct,
    );
    return [for (final model in models) _bookFromModel(model)];
  }

  @override
  Future<List<String>> listTopicTags() async {
    final systems = await _loadTagSystems(_client, kBookModelTypeName);
    final topic = _findTagSystem(systems, kBookTopicTagSystem);
    if (topic != null) return _flattenTagNodes(topic.nodes);

    final documentSystems = await _loadTagSystems(_client, 'Document');
    final documentTopic = _findTagSystem(documentSystems, kBookTopicTagSystem);
    if (documentTopic == null) return const [];
    return _flattenTagNodes(documentTopic.nodes);
  }

  @override
  Future<NxBook> createBook({String? title}) async {
    final rows = await listBooks();
    final rank = _nextRank(rows, BookReadingState.toRead);
    final name = _bookTitleOrFallback(title);
    final id = await setKgqlModel(
      _client,
      SetModelRequest(
        modelType: kBookModelTypeName,
        name: name,
        description: '',
        attributes: [
          SetModelAttribute(key: kBookAttrDocument, value: ''),
          SetModelAttribute(
            key: kBookAttrJsonDocument,
            value: _blankDocumentJson(),
          ),
          SetModelAttribute(key: kBookAttrPinned, value: false),
          SetModelAttribute(key: kBookAttrShareToWeb, value: false),
          SetModelAttribute(
            key: kBookAttrReadingState,
            value: BookReadingState.toRead.kgqlValue,
          ),
          SetModelAttribute(key: kBookAttrRank, value: rank),
        ],
      ),
    );
    final now = DateTime.now();
    return NxBook(
      id: id,
      title: name,
      description: '',
      tags: const [],
      readingState: BookReadingState.toRead,
      rank: rank,
      totalChapters: null,
      currentChapter: null,
      wordCount: 0,
      updatedAt: now,
      updatedLabel: _relativeLabel(now),
    );
  }

  @override
  Future<void> updateBookState({
    required int id,
    required BookReadingState state,
    required int rank,
  }) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: id,
        attributes: [
          SetModelAttribute(key: kBookAttrReadingState, value: state.kgqlValue),
          SetModelAttribute(key: kBookAttrRank, value: rank),
        ],
      ),
    );
  }

  @override
  Future<void> updateBookRank({required int id, required int rank}) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: id,
        attributes: [SetModelAttribute(key: kBookAttrRank, value: rank)],
      ),
    );
  }

  @override
  Future<void> updateBookTopicTags({
    required int id,
    required List<String> tags,
  }) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: id,
        tags: [
          SetModelTag(
            system: kBookTopicTagSystem,
            nodes: _normalizeTagList(tags),
            clear: true,
          ),
        ],
      ),
    );
  }

  @override
  Future<void> updateBookChapterProgress({
    required int id,
    required int? totalChapters,
    required int? currentChapter,
  }) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: id,
        attributes: [
          if (totalChapters == null)
            SetModelAttribute(key: kBookAttrTotalChapters, delete: true)
          else
            SetModelAttribute(
              key: kBookAttrTotalChapters,
              value: totalChapters,
            ),
          if (currentChapter == null)
            SetModelAttribute(key: kBookAttrCurrentChapter, delete: true)
          else
            SetModelAttribute(
              key: kBookAttrCurrentChapter,
              value: currentChapter,
            ),
        ],
      ),
    );
  }

  @override
  Future<void> deleteBook(int id) async {
    await setKgqlModel(_client, SetModelRequest(id: id, delete: true));
  }

  static const Map<String, dynamic> bookSummaryFetchStruct = {
    'id': true,
    'name': true,
    'description': true,
    'created_at': true,
    'updated_at': true,
    kBookAttrWordCount: true,
    kBookAttrReadingState: true,
    kBookAttrRank: true,
    kBookAttrTotalChapters: true,
    kBookAttrCurrentChapter: true,
    'tags': true,
  };
}

Future<List<TagSystem>> _loadTagSystems(
  GraphQLClient client,
  String modelTypeName,
) async {
  final schema = await fetchKgqlModelTypeByName(
    client,
    modelTypeName,
    struct: const {'id': true, 'name': true, 'tag_systems': true},
  );
  return schema.tagSystems ?? const [];
}

TagSystem? _findTagSystem(List<TagSystem> systems, String name) {
  for (final system in systems) {
    if (system.name == name) return system;
  }
  return null;
}

NxBook _bookFromModel(Model model) {
  final updatedAt =
      DateTime.tryParse(model.updatedAt ?? '') ??
      DateTime.tryParse(model.createdAt ?? '') ??
      DateTime.now();
  return NxBook(
    id: model.id,
    title: model.name,
    description: model.description?.trim() ?? '',
    tags: _flattenTags(model.tags),
    readingState: BookReadingState.fromKgql(
      model.attrString(kBookAttrReadingState),
    ),
    rank: model.attrInt(kBookAttrRank),
    totalChapters: model.attrInt(kBookAttrTotalChapters),
    currentChapter: model.attrInt(kBookAttrCurrentChapter),
    wordCount: model.attrInt(kBookAttrWordCount) ?? 0,
    updatedAt: updatedAt,
    updatedLabel: _relativeLabel(updatedAt),
  );
}

List<String> _flattenTags(Map<String, List<String>>? tagsBySystem) {
  if (tagsBySystem == null || tagsBySystem.isEmpty) return const [];
  final topicTags = tagsBySystem['Topic'];
  if (topicTags == null || topicTags.isEmpty) return const [];
  final seen = <String>{};
  final result = <String>[];
  for (final value in topicTags) {
    final tag = value.trim();
    if (tag.isEmpty || !seen.add(tag.toLowerCase())) continue;
    result.add(tag);
  }
  result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
}

List<String> _flattenTagNodes(List<TagNode> nodes) {
  final tags = <String>[];
  void visit(TagNode node) {
    tags.add(node.name);
    for (final child in node.children ?? const <TagNode>[]) {
      visit(child);
    }
  }

  for (final node in nodes) {
    visit(node);
  }
  return _normalizeTagList(tags);
}

List<String> _normalizeTagList(List<String> tags) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in tags) {
    final tag = value.trim();
    if (tag.isEmpty || !seen.add(tag.toLowerCase())) continue;
    result.add(tag);
  }
  result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
}

int _nextRank(List<NxBook> books, BookReadingState state) {
  final ranks = [
    for (final book in books)
      if (book.readingState == state && book.rank != null) book.rank!,
  ];
  if (ranks.isEmpty) return 0;
  return ranks.reduce((a, b) => a > b ? a : b) + 1;
}

String _bookTitleOrFallback(String? title) {
  final trimmed = title?.trim();
  return trimmed == null || trimmed.isEmpty ? 'Untitled book' : trimmed;
}

Map<String, dynamic> _blankDocumentJson() {
  return <String, dynamic>{
    'format': 'appflowy_document',
    'document': <String, dynamic>{
      'type': 'page',
      'children': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'paragraph',
          'data': <String, dynamic>{
            'delta': <Map<String, dynamic>>[
              <String, dynamic>{'insert': ''},
            ],
          },
        },
      ],
    },
  };
}

String _relativeLabel(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${time.month}/${time.day}/${time.year}';
}
