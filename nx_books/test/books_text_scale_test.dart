import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/settings/books_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('reading scale is shared and restored from this device', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    expect(first.read(booksTextScaleProvider), 1);
    await tester.pumpAndSettle();
    first.read(booksTextScaleProvider.notifier).increase();
    await tester.pumpAndSettle();
    expect(first.read(booksTextScaleProvider), 1.1);
    expect(
      (await SharedPreferences.getInstance()).getDouble(
        BooksTextScaleNotifier.preferenceKey,
      ),
      1.1,
    );
    first.dispose();
    final reopened = ProviderContainer();
    reopened.read(booksTextScaleProvider);
    await tester.pumpAndSettle();
    expect(reopened.read(booksTextScaleProvider), 1.1);
    reopened.dispose();
  });
}
