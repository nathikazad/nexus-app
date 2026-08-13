/// GraphQL document for `resolve_model_type_domain_options`.
const String resolveModelTypeDomainOptionsQuery = '''
query ResolveModelTypeDomainOptions(\$modelTypeName: String) {
  resolveModelTypeDomainOptions(modelTypeName: \$modelTypeName)
}
''';
