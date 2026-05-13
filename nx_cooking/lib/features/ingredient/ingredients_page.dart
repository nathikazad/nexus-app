import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/data/providers.dart';

/// Lists all [Item] models with the CookingItem trait (searchable).
class IngredientsPage extends ConsumerStatefulWidget {
  const IngredientsPage({super.key});

  @override
  ConsumerState<IngredientsPage> createState() => _IngredientsPageState();
}

class _IngredientsPageState extends ConsumerState<IngredientsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(cookingItemsProvider);
    final q = _searchController.text.trim().toLowerCase();

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (items) {
        final filtered = q.isEmpty
            ? items
            : items.where((e) => e.name.toLowerCase().contains(q)).toList();

        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 12),
                child: Row(
                  children: [
                    if (context.canPop())
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.zinc500,
                          size: 22,
                        ),
                        onPressed: () => context.pop(),
                      ),
                    Expanded(
                      child: Text(
                        'Ingredients',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.zinc900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search ingredients…',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.zinc400,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: AppColors.zinc400,
                  ),
                  filled: true,
                  fillColor: AppColors.zinc50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.zinc200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.zinc200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.orange500,
                      width: 1.2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.zinc100),
            Expanded(
              child: ColoredBox(
                color: AppColors.zinc50.withValues(alpha: 0.5),
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          items.isEmpty ? 'No ingredients yet.' : 'No matches',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.zinc500,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppColors.zinc100),
                        itemBuilder: (context, i) {
                          final e = filtered[i];
                          return Material(
                            color: Colors.white,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              title: Text(
                                e.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.zinc900,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );

        return Scaffold(backgroundColor: Colors.white, body: body);
      },
    );
  }
}
