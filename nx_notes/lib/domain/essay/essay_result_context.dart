import 'package:nx_notes/domain/essay/essay_query.dart';
import 'package:nx_notes/domain/essay/essay.dart';

class EssayResultContext {
  const EssayResultContext({
    required this.title,
    required this.query,
    required this.resultIds,
    this.results = const <Essay>[],
  });

  final String title;
  final EssayQuery query;
  final List<int> resultIds;
  final List<Essay> results;
}
