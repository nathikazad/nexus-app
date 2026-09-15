import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_cooking/core/layout/layout.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/data/providers.dart';

class RecipesPage extends ConsumerWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recipeListProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load recipes: $e',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (list) => ListView.separated(
        padding: const EdgeInsets.only(bottom: CookingLayout.bottomNavExtra),
        itemCount: list.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.zinc100),
        itemBuilder: (context, i) {
          final r = list[i];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/recipe/${r.id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.zinc900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.metaLine,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.zinc500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
