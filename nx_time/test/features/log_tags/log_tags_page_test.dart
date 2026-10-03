import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_time/data/log/log_schema_view_provider.dart';
import 'package:nx_time/domain/schema/model_type_view.dart';
import 'package:nx_time/features/log_tags/log_tags_page.dart';

void main() {
  testWidgets(
    'opens and goes back with a plain Navigator; shows genuine empty state',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            logSchemaViewProvider.overrideWith(
              (ref) async => const ModelTypeView(id: 1, name: 'Daily Log'),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LogTagsPage()),
                  ),
                  child: const Text('Open tags'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open tags'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Daily log tags'), findsOneWidget);
      expect(find.textContaining('No tag systems'), findsOneWidget);
      expect(find.text('Priority'), findsNothing);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Open tags'), findsOneWidget);
    },
  );
}
