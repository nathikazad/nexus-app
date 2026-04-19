import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/images/image_repository.dart';
import 'package:nexus_voice_assistant/domain/images/image_repository.dart' as domain;

void main() {
  test('HttpImageRepository implements domain ImageRepository', () {
    expect(HttpImageRepository(), isA<domain.ImageRepository>());
  });
}
