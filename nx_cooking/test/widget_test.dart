import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cooking/app.dart';
import 'package:nx_cooking/core/dates/week_calendar.dart';
import 'package:nx_cooking/data/fake_recipe_repository.dart';
import 'package:nx_cooking/data/providers.dart';
import 'package:nx_cooking/domain/shopping.dart';
import 'package:nx_cooking/domain/week_section.dart';
import 'package:nx_db/auth.dart';

class _TestAuthController extends AuthController {
  @override
  Future<User?> build() async {
    return User(userId: '1', preset: BackendPreset.localhost);
  }
}

List<WeekDaySection> _stubWeek() {
  final start = weekStartMonday(DateTime(2025, 4, 25));
  return List.generate(
    7,
    (i) => WeekDaySection(
      date: start.add(Duration(days: i)),
      dayLabel: 'Day',
      isToday: false,
      meal: null,
    ),
  );
}

void main() {
  testWidgets('Cooking shell loads', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _TestAuthController()),
          recipeRepositoryProvider.overrideWithValue(FakeRecipeRepository()),
          weekSectionsProvider.overrideWith((ref) async => _stubWeek()),
          shoppingSnapshotProvider.overrideWith(
            (ref) async => const ShoppingListSnapshot(
              purchasedCount: 0,
              totalCount: 0,
              groups: [],
            ),
          ),
        ],
        child: const NexusCookingApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Week'), findsWidgets);
  });
}
