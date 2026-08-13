/// One image for a day, with URL and time derived from filename.
class ImageEntry {
  const ImageEntry({
    required this.url,
    required this.filename,
    required this.minutesSinceMidnight,
    this.currentApp,
  });

  final String url;
  final String filename;

  /// Fractional minutes since local midnight (seconds included as fraction).
  final double minutesSinceMidnight;

  /// Frontmost app name from `payload.current_app` (desktop screenshots), if present.
  final String? currentApp;
}
