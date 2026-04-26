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
      data: (list) => Stack(
        children: [
          ListView.separated(
            padding: const EdgeInsets.only(
              bottom: CookingLayout.bottomNavExtra + 88,
            ),
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
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
                        const SizedBox(width: 8),
                        Wrap(
                          spacing: 5,
                          children: r.tags
                              .map(
                                (t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.orange100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    t.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 9.6,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      color: AppColors.orange800,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            right: 20,
            bottom: 20 + MediaQuery.paddingOf(context).bottom,
            child: Material(
              color: AppColors.orange500,
              borderRadius: BorderRadius.circular(999),
              elevation: 4,
              shadowColor: AppColors.orange500.withValues(alpha: 0.25),
              child: InkWell(
                onTap: () => context.push('/recipe/new'),
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
