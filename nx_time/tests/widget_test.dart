// Host-side smoke test: `flutter test tests/widget_test.dart`

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/app.dart';

void main() {
  testWidgets('Today tab renders heading and first activity', (tester) async {
    await tester.pumpWidget(const NxTimeApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Today — Thu, Oct 26'), findsOneWidget);
    expect(find.text('Activities'), findsOneWidget);
    expect(find.text('Deep sleep'), findsOneWidget);
  });
}
