@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/nx_db.dart';
import 'package:test/test.dart' show Tags;

void main() {
  test('createClient returns GraphQLClient', () {
    final c = createClient('http://127.0.0.1:5001/graphql', '1');
    expect(c, isNotNull);
  });
}
