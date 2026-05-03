import 'package:nx_notes/domain/essay/essay_query.dart';

class EssayResultContext {
  const EssayResultContext({
    required this.title,
    required this.query,
    required this.resultIds,
  });

  final String title;
  final EssayQuery query;
  final List<int> resultIds;
}
