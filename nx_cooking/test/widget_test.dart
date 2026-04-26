import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cooking/app.dart';
import 'package:nx_cooking/data/fake_recipe_repository.dart';
import 'package:nx_cooking/data/providers.dart';

void main() {
  testWidgets('Cooking shell loads', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recipeRepositoryProvider.overrideWithValue(FakeRecipeRepository()),
        ],
        child: const NexusCookingApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Week'), findsWidgets);
  });
}
