import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexus_voice_assistant/data/schema/kgql_model_type_repository.dart';
import 'package:nexus_voice_assistant/domain/schema/attribute_definition_draft.dart';
import 'package:nx_db/nx_db.dart';

import '../../_support/mock_graphql_client.dart';

class _AuthLoggedIn extends AuthController {
  _AuthLoggedIn() : super(initialDelay: Duration.zero, skipBackendPing: true);
  @override
  Future<User?> build() async => User(
        userId: '1',
        preset: BackendPreset.localhost,
      );
}

void main() {
  setUpAll(registerGraphqlFallbacks);

  group('KgqlModelTypeRepository', () {
    test('setModelType parses id from json string', () async {
      final mock = MockGraphQLClient();
      when(() => mock.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          options: MutationOptions(document: gql('mutation { __typename }')),
          source: QueryResultSource.network,
          data: {
            'setKgqlModelTypes': {'json': '{"id": 42}'},
          },
        ),
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_AuthLoggedIn.new),
          graphqlClientProvider.overrideWithValue(mock),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);

      final repo = container.read(modelTypeWriteRepositoryProvider);
      final id = await repo.setModelType(
        name: 'N',
        typeKind: 'base',
        attributeDefinitions: const [],
        relationshipTypes: const [],
      );
      expect(id, 42);
      verify(() => mock.mutate(any())).called(1);
    });

    test('setModelType parses id from json map', () async {
      final mock = MockGraphQLClient();
      when(() => mock.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          options: MutationOptions(document: gql('mutation { __typename }')),
          source: QueryResultSource.network,
          data: {
            'setKgqlModelTypes': {
              'json': {'id': 99},
            },
          },
        ),
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_AuthLoggedIn.new),
          graphqlClientProvider.overrideWithValue(mock),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);

      final repo = container.read(modelTypeWriteRepositoryProvider);
      final id = await repo.setModelType(
        id: 5,
        name: 'X',
        typeKind: 'trait',
        attributeDefinitions: const [
          AttributeDefinitionDraft(key: 'a', valueType: 'string'),
        ],
        relationshipTypes: const [],
      );
      expect(id, 99);
    });

    test('setModelType throws when GraphQL reports exception', () async {
      final mock = MockGraphQLClient();
      when(() => mock.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          options: MutationOptions(document: gql('mutation { __typename }')),
          source: QueryResultSource.network,
          exception: OperationException(),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_AuthLoggedIn.new),
          graphqlClientProvider.overrideWithValue(mock),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);

      final repo = container.read(modelTypeWriteRepositoryProvider);
      expect(
        () => repo.setModelType(
          name: 'N',
          typeKind: 'base',
          attributeDefinitions: const [],
          relationshipTypes: const [],
        ),
        throwsException,
      );
    });

    test('setModelType throws when id missing in response', () async {
      final mock = MockGraphQLClient();
      when(() => mock.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          options: MutationOptions(document: gql('mutation { __typename }')),
          source: QueryResultSource.network,
          data: {
            'setKgqlModelTypes': {'json': '{}'},
          },
        ),
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_AuthLoggedIn.new),
          graphqlClientProvider.overrideWithValue(mock),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);

      final repo = container.read(modelTypeWriteRepositoryProvider);
      expect(
        () => repo.setModelType(
          name: 'N',
          typeKind: 'base',
          attributeDefinitions: const [],
          relationshipTypes: const [],
        ),
        throwsException,
      );
    });

    test('deleteModelType succeeds when GraphQL has no exception', () async {
      final mock = MockGraphQLClient();
      when(() => mock.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          options: MutationOptions(document: gql('mutation { __typename }')),
          source: QueryResultSource.network,
          data: {
            'deleteModelTypeById': {
              'modelType': {'id': 7},
            },
          },
        ),
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_AuthLoggedIn.new),
          graphqlClientProvider.overrideWithValue(mock),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);

      final repo = container.read(modelTypeWriteRepositoryProvider);
      await repo.deleteModelType(7);
      verify(() => mock.mutate(any())).called(1);
    });

    test('deleteModelType throws when GraphQL reports exception', () async {
      final mock = MockGraphQLClient();
      when(() => mock.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          options: MutationOptions(document: gql('mutation { __typename }')),
          source: QueryResultSource.network,
          exception: OperationException(),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_AuthLoggedIn.new),
          graphqlClientProvider.overrideWithValue(mock),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);

      final repo = container.read(modelTypeWriteRepositoryProvider);
      expect(() => repo.deleteModelType(1), throwsException);
    });
  });
}
