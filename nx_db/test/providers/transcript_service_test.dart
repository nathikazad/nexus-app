@Tags(['providers'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart' show Tags;

import 'package:nx_db/src/data_providers/transcript_provider.dart';

void main() {
  group('PX transcript service', () {
    test('PX10.1 getCurrentTranscript query shape', () {
      expect(getCurrentTranscriptQuery, contains('getCurrentTranscript'));
      expect(getCurrentTranscriptQuery, contains(r'$userIdParam'));
      expect(getCurrentTranscriptQuery, contains('userIdParam'));
    });

    test('PX10.2 parseTranscriptFromGraphqlResponse string JSON', () {
      final raw = '{"id": 7, "messages": {}}';
      final t = parseTranscriptFromGraphqlResponse(raw);
      expect(t, isNotNull);
      expect(t!.id, 7);
    });

    test('PX10.2 parseTranscriptFromGraphqlResponse json wrapper', () {
      final t = parseTranscriptFromGraphqlResponse({
        'json': '{"id": 3, "messages": {}}',
      });
      expect(t, isNotNull);
      expect(t!.id, 3);
    });

    test('PX10.3 unauthenticated getTranscript throws', () async {
      SharedPreferences.setMockInitialValues({});
      await expectLater(
        TranscriptService.getTranscript(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'msg',
            contains('not authenticated'),
          ),
        ),
      );
    });

    test('PX10.4 addMessageToTranscript mutation shape', () {
      expect(addMessageToTranscriptMutation, contains('addMessageToTranscript'));
      expect(addMessageToTranscriptMutation, contains(r'$input'));
      expect(addMessageToTranscriptMutation, contains('AddMessageToTranscriptInput'));
    });
  });
}
