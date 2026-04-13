import 'package:nx_db/nx_db.dart';

/// Client-side filter: [query] must be lowercased trimmed substring match on
/// [Model.name] or [Model.description] only.
List<Model> filterExpenseModelsBySearch(List<Model> models, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return models;

  bool matches(Model m) {
    if (m.name.toLowerCase().contains(q)) return true;
    final d = m.description;
    if (d != null && d.isNotEmpty && d.toLowerCase().contains(q)) return true;
    return false;
  }

  return models.where(matches).toList();
}
