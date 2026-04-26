import 'package:flutter/material.dart';
import 'package:nx_cooking/domain/recipe_detail.dart';
import 'package:nx_cooking/features/recipe_edit/recipe_edit_page.dart';

class RecipeCreatePage extends StatelessWidget {
  const RecipeCreatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return RecipeFormPage(initial: RecipeFormData.empty(), isCreate: true);
  }
}
