import 'dart:math' as math;

/// An indivisible vertical interval: one laid-out text line or image.
class PageSpan {
  const PageSpan(this.top, this.bottom);
  final double top;
  final double bottom;
}

/// Contiguous page offsets. Never split a line/image or silently drop content.
List<double> pageBreaks(
    double contentHeight, double pageHeight, List<PageSpan> spans) {
  if (pageHeight <= 0 || !pageHeight.isFinite || !contentHeight.isFinite) {
    throw ArgumentError('Pagination requires finite positive dimensions');
  }
  final breaks = <double>[0];
  while (breaks.last < contentHeight - 0.01) {
    final start = breaks.last;
    var end = math.min(start + pageHeight, contentHeight);
    var changed = true;
    while (changed) {
      changed = false;
      for (final span in spans) {
        if (span.top < end - 0.01 && span.bottom > end + 0.01) {
          end = span.top;
          changed = true;
        }
      }
    }
    if (end <= start + 0.01) {
      throw StateError(
          'An item is taller than the page. Reduce the text size or enlarge the window.');
    }
    breaks.add(end);
  }
  if (breaks.length == 1) breaks.add(0);
  return breaks;
}
