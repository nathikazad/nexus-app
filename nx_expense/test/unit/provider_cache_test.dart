import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_expense/data/providers.dart';

void main() {
  test('E10.4 concurrent reads of expenseStructProvider share cached map', () async {
    final fixture = ModelType.fromJson({
      'id': 9,
      'name': 'Expense',
      'attributes': [
        {'key': 'cost', 'value_type': 'number'},
      ],
    }, recursive: true);

    final container = ProviderContainer(
      overrides: [
        expenseSchemaProvider.overrideWith((ref) async => fixture),
      ],
    );
    addTearDown(container.dispose);

    await container.read(expenseSchemaProvider.future);
    final a = container.read(expenseStructProvider);
    final b = container.read(expenseStructProvider);
    expect(identical(a, b), isTrue);
  });
}
