import 'package:nx_notes/domain/document/document_query.dart';
import 'package:nx_notes/domain/document/document.dart';

class DocumentResultContext {
  const DocumentResultContext({
    required this.title,
    required this.query,
    required this.resultIds,
    this.results = const <NxDocument>[],
  });

  final String title;
  final DocumentQuery query;
  final List<int> resultIds;
  final List<NxDocument> results;
}
