@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/internal.dart';
import 'package:test/test.dart' show Tags;

void main() {
  group('KGQL documents parse with gql()', () {
    test('get_kgql_models', () {
      final d = gql(kgqlGetKgqlModelsQuery);
      expect(d.definitions, isNotEmpty);
      expect(kgqlGetKgqlModelsQuery, contains(r'$filter'));
      expect(kgqlGetKgqlModelsQuery, contains(r'$struct'));
      expect(kgqlGetKgqlModelsQuery, contains(r'$domainId'));
    });

    test('set_kgql_models', () {
      gql(setKgqlModelsMutation);
      expect(setKgqlModelsMutation, contains(r'$input'));
    });

    test('get_kgql_model_type', () {
      gql(kgqlGetKgqlModelTypeQuery);
      expect(kgqlGetKgqlModelTypeQuery, contains(r'$domainId'));
    });

    test('get_all_model_types', () {
      gql(getAllModelTypesQuery);
      expect(getAllModelTypesQuery, contains('getKgqlModelType'));
      expect(getAllModelTypesQuery, contains(r'$domainId'));
    });

    test('set_kgql_model_type', () {
      gql(setKgqlModelTypesMutation);
      expect(setKgqlModelTypesMutation, contains(r'$input'));
    });

    test('get_kgql_aggregate', () {
      gql(getKgqlAggregateQuery);
      expect(getKgqlAggregateQuery, contains(r'$filterkgql'));
      expect(getKgqlAggregateQuery, contains(r'$aggregate'));
      expect(getKgqlAggregateQuery, contains(r'$domainId'));
    });

    test('get_current_transcript', () {
      gql(getCurrentTranscriptQuery);
      expect(getCurrentTranscriptQuery, contains(r'$userIdParam'));
    });

    test('add_message_to_transcript', () {
      gql(addMessageToTranscriptMutation);
      expect(addMessageToTranscriptMutation, contains(r'$input'));
    });

    test('transcript_message_subscription', () {
      gql(transcriptMessageAddedSubscription);
      expect(transcriptMessageAddedSubscription, contains(r'$transcriptId'));
    });
  });
}
