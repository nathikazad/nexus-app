@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/transcript.dart';
import 'package:test/test.dart' show Tags;

void main() {
  test('parseTranscriptFromGraphqlResponse string JSON', () {
    final raw = '{"id": 7, "messages": {}}';
    final t = parseTranscriptFromGraphqlResponse(raw);
    expect(t, isNotNull);
    expect(t!.id, 7);
  });

  test('parseTranscriptFromGraphqlResponse json wrapper', () {
    final t = parseTranscriptFromGraphqlResponse({
      'json': '{"id": 3, "messages": {}}',
    });
    expect(t, isNotNull);
    expect(t!.id, 3);
  });

  test('parseTranscriptFromGraphqlResponse null', () {
    expect(parseTranscriptFromGraphqlResponse(null), isNull);
  });
}
