@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/transcript.dart';
import 'package:test/test.dart' show Tags;

void main() {
  test('transcript barrel re-exports service and parser', () {
    expect(TranscriptService, isNotNull);
    expect(parseTranscriptFromGraphqlResponse(null), isNull);
  });
}
