import 'dart:convert';

import 'package:graphql_flutter/graphql_flutter.dart';

String _prettyJson(Object? value) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(value);
}

void printKgqlMutationError({
  required String operationName,
  required String mutation,
  required Map<String, dynamic> variables,
  required OperationException exception,
}) {
  print('KGQL mutation error: $operationName');
  print('Mutation:');
  print(mutation);
  print('Variables:');
  print(_prettyJson(variables));
  print('Error: $exception');
  for (final error in exception.graphqlErrors) {
    print('GraphQL error: ${error.message}');
    if (error.extensions != null) {
      print('Extensions: ${_prettyJson(error.extensions)}');
    }
  }
  if (exception.linkException != null) {
    print('Link exception: ${exception.linkException}');
  }
}
