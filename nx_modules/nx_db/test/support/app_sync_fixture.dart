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
        'projection_version': 3,
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
      'projection_version': 3,
      'collections': {},
      'manifest': [
        for (final item in items)
          {
            'id': 'model:${item['id']}',
            'hash': item['hash'],
            'model_type': item['payload']['model_type']['name'],
            'collections': [''],
          },
      ],
      'items': ids == null
          ? []
          : [
              for (final item in items)
                if (ids.contains('model:${item['id']}'))
                  {...item, 'id': 'model:${item['id']}'},
            ],
    },
  };
}
