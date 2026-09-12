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
        // A malformed EPUB can expose a whole table, quote, or nested HTML
        // placeholder as one atomic render span. There is no legal break that
        // keeps an item taller than the viewport intact, so let the viewport
        // clip it into contiguous slices. The next page resumes at the exact
        // vertical offset, preserving all content instead of failing the book.
        if (span.bottom - span.top > pageHeight + 0.01) continue;
        if (span.top < end - 0.01 && span.bottom > end + 0.01) {
          end = span.top;
          changed = true;
        }
      }
    }
    if (end <= start + 0.01) end = math.min(start + pageHeight, contentHeight);
    breaks.add(end);
  }
  if (breaks.length == 1) breaks.add(0);
  return breaks;
}
