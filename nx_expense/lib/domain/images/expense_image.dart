class ImageModelLink {
  const ImageModelLink({
    required this.id,
    required this.name,
    required this.type,
  });
  final int id;
  final String name;
  final String type;
}

class ExpenseImage {
  const ExpenseImage({
    required this.id,
    required this.time,
    required this.filename,
    this.links = const [],
  });
  final String id;
  final DateTime time;
  final String filename;
  final List<ImageModelLink> links;
  bool get isLinked => links.isNotEmpty;
}
