import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_expense/data/recipe/import_recipe_api.dart';
import 'package:nx_expense/data/teller/teller_sync_api.dart';

void main() {
  group('WAN HTTP routes', () {
    test('Teller sync posts to pi WAN HTTP host', () async {
      final base = resolve(BackendPreset.piWan).imageHttp;
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://http.supacharger.ai/teller/sync',
        );
        expect(request.headers['x-user-id'], '1');
        return http.Response('{"ok":true}', 200);
      });

      await postTellerSync(imageBaseUrl: base, userId: '1', httpClient: client);
    });

    test('Recipe import posts to pi WAN HTTP host', () async {
      final base = resolve(BackendPreset.piWan).imageHttp;
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://http.supacharger.ai/import-recipe',
        );
        expect(request.headers['x-user-id'], '1');
        expect(jsonDecode(request.body), {'text': 'ingredients'});
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

      final result = await importRecipeFromPastedText(
        imageBaseUrl: base,
        userId: '1',
        recipeText: 'ingredients',
        httpClient: client,
      );

      expect(result.recipeId, 42);
    });
  });
}
