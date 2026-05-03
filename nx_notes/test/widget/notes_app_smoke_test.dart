import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/app.dart';

void main() {
  testWidgets('notes app renders the desktop or mobile shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: NexusNotesApp()));
    await tester.pumpAndSettle();

    expect(find.text('nx_notes'), findsWidgets);
  });
}
