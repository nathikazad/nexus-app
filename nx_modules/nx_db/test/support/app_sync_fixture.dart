/// Converts test content into the published-state protocol used by all apps.
Map<String, dynamic> appSyncFixture(
  Map<String, dynamic> variables,
  List<Map<String, dynamic>> items,
) {
  if (!variables.containsKey('revision')) {
    return {
      'appSyncState': {
        'status': 'ready',
        'revision': 1,
        'projection_version': 2,
        'root_hash': 'fixture-root',
        'collections': {
          '': {
            'hash': 'fixture-group',
            'parent': null,
            'count': items.length,
            'child_count': 0,
          },
        },
      },
    };
  }
  final ids = variables['itemIds'] as List?;
  return {
    'appSyncSnapshot': {
      'status': 'ready',
      'revision': 1,
      'projection_version': 2,
      'collections': {},
      'manifest': [
        for (final item in items)
          {
            'id': item['id'],
            'hash': item['hash'],
            'model_type': item['payload']['model_type']['name'],
            'collections': [''],
          },
      ],
      'items': ids == null
          ? []
          : items.where((item) => ids.contains(item['id'])).toList(),
    },
  };
}
