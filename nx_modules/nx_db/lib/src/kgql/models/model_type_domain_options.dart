class ModelTypeDomainOption {
  const ModelTypeDomainOption({
    required this.id,
    required this.name,
    required this.kind,
    required this.source,
  });

  final int id;
  final String name;
  final String kind;
  final String source;

  factory ModelTypeDomainOption.fromJson(Map<String, dynamic> json) {
    return ModelTypeDomainOption(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }
}

class ModelTypeDomainOptions {
  const ModelTypeDomainOptions({
    required this.modelType,
    required this.domains,
  });

  final String? modelType;
  final List<ModelTypeDomainOption> domains;

  factory ModelTypeDomainOptions.fromJson(Map<String, dynamic> json) {
    final rawDomains = json['domains'];
    final domains = rawDomains is List
        ? rawDomains
            .map((e) => ModelTypeDomainOption.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList()
        : <ModelTypeDomainOption>[];
    return ModelTypeDomainOptions(
      modelType: json['model_type'] as String? ?? json['modelType'] as String?,
      domains: domains,
    );
  }
}
