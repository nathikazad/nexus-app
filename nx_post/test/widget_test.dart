import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_post/main.dart';

void main() {
  testWidgets('renders feed shell and opens compose sheet', (tester) async {
    await tester.pumpWidget(const NexusPostApp());

    expect(find.text('nx_post'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);

    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Feed'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('New microblog'), findsOneWidget);
    expect(find.text('Save microblog'), findsOneWidget);
  });
}
