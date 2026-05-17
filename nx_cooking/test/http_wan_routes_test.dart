import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_cooking/data/recipe/import_recipe_api.dart';
import 'package:nx_db/auth.dart';

void main() {
  test('Recipe import posts to pi WAN HTTP host', () async {
    final base = resolve(BackendPreset.piWan).imageHttp;
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://http.supacharger.ai/import-recipe',
      );
      expect(request.headers['x-user-id'], '1');
      expect(jsonDecode(request.body), {'url': 'https://example.com/recipe'});
      return http.Response(
        jsonEncode({
          'ok': true,
          'recipe_id': 42,
          'created_item_ids': <int>[],
          'recipe': <String, dynamic>{'name': 'Test'},
        }),
        200,
      );
    });

    final result = await importRecipeFromUrl(
      imageBaseUrl: base,
      userId: '1',
      recipeUrl: 'https://example.com/recipe',
      httpClient: client,
    );

    expect(result.recipeId, 42);
  });
}
