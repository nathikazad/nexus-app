import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/nx_db.dart';

void main() {
  test('ImageEntry exposes url and minutes', () {
    const e = ImageEntry(
      url: 'http://x/a.jpg',
      filename: 'a.jpg',
      minutesSinceMidnight: 90.5,
      currentApp: 'Finder',
    );
    expect(e.minutesSinceMidnight, 90.5);
    expect(e.currentApp, 'Finder');
  });
}
