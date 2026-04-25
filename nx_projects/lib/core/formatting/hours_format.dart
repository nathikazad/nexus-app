/// e.g. "4h" / "1.5h"
String formatHours(double h) {
  if (h == h.roundToDouble()) {
    return '${h.toInt()}h';
  }
  return '${h}h';
}
