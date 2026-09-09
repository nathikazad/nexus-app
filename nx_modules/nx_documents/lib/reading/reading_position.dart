/// Viewport anchor owned by the reader. Persistence belongs to the host app.
class ReadingPosition {
  const ReadingPosition({required this.index, this.alignment = 0});
  final int index;
  final double alignment;
}
