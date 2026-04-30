import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/nx_db.dart';

void main() {
  test('HttpImageRepository implements ImageRepository', () {
    expect(HttpImageRepository(), isA<ImageRepository>());
  });
}
