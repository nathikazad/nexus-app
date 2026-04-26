import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cooking/app.dart';

void main() {
  testWidgets('Cooking shell loads', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: NexusCookingApp()),
    );
    await tester.pump();
    expect(find.text('Week'), findsWidgets);
  });
}
