import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_cooking/core/dates/week_calendar.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/data/providers.dart';
import 'package:nx_cooking/domain/recipe_filter.dart';
import 'package:nx_cooking/domain/search_result.dart';
import 'package:nx_cooking/features/buy/buy_page.dart';
import 'package:nx_cooking/features/recipes/recipe_list_filter_sheet.dart';
import 'package:nx_cooking/features/recipes/recipes_page.dart';
import 'package:nx_cooking/features/stats/stats_page.dart';
import 'package:nx_cooking/features/week/week_page.dart';
import 'package:nx_db/auth.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

const _tabTitles = ['Week', 'Recipes', 'Buy', 'Stats'];

/// Bottom-nav scaffold per `reference/index.html` + [nx_time] `AppShell` pattern.
class CookingShell extends ConsumerStatefulWidget {
  const CookingShell({super.key});

  @override
  ConsumerState<CookingShell> createState() => _CookingShellState();
}

class _CookingShellState extends ConsumerState<CookingShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _TopBar(
            title: _tabTitles[_index],
            onLogout: () => ref.read(authProvider.notifier).logout(),
            onOpenTagSystems: () => context.push('/tag-systems'),
            onOpenIngredients: () => context.push('/ingredients'),
          ),
          if (_index == 0)
            Consumer(
              builder: (context, ref, _) {
                final start = ref.watch(selectedWeekStartProvider);
                return _WeekSubBar(
                  label: formatWeekRangeLabel(start),
                  onPrev: () => ref
                      .read(selectedWeekStartProvider.notifier)
                      .shiftWeeks(-1),
                  onNext: () => ref
                      .read(selectedWeekStartProvider.notifier)
                      .shiftWeeks(1),
                );
              },
            ),
          if (_index == 1) const _RecipesSubBar(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                WeekPage(),
                RecipesPage(),
                BuyPage(),
                StatsPage(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onLogout,
    required this.onOpenTagSystems,
    required this.onOpenIngredients,
  });

  final String title;
  final VoidCallback onLogout;
  final VoidCallback onOpenTagSystems;
  final VoidCallback onOpenIngredients;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.orange100)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                const SizedBox(width: 28),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.orange500,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Account',
                  onSelected: (value) {
                    if (value == 'tags') onOpenTagSystems();
                    if (value == 'ingredients') onOpenIngredients();
                    if (value == 'logout') onLogout();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'tags', child: Text('Tags')),
                    PopupMenuItem(
                      value: 'ingredients',
                      child: Text('Ingredients'),
                    ),
                    PopupMenuItem(value: 'logout', child: Text('Log out')),
                  ],
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.orange50,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.orange200.withValues(alpha: 0.6),
                      ),
                    ),
                    child: const Icon(
                      SolarLinearIcons.userRounded,
                      size: 16,
                      color: AppColors.orange500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekSubBar extends StatelessWidget {
  const _WeekSubBar({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.zinc100)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: onPrev,
              style: IconButton.styleFrom(foregroundColor: AppColors.zinc400),
              icon: const Icon(SolarLinearIcons.altArrowLeft, size: 20),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: AppColors.zinc800,
              ),
            ),
            IconButton(
              onPressed: onNext,
              style: IconButton.styleFrom(foregroundColor: AppColors.zinc400),
              icon: const Icon(SolarLinearIcons.altArrowRight, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipesSubBar extends ConsumerStatefulWidget {
  const _RecipesSubBar();

  @override
  ConsumerState<_RecipesSubBar> createState() => _RecipesSubBarState();
}

class _RecipesSubBarState extends ConsumerState<_RecipesSubBar> {
  late final TextEditingController _searchController;
  final Object _searchTapGroup = Object();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(recipeSearchQueryProvider.notifier).clear();
  }

  void _mergeTagFilter(TagSearchHit hit) {
    final current = ref.read(recipeListFilterProvider);
    final maps = <Map<String, dynamic>>[
      if (current?.tagFilters != null) ...current!.tagFilters!,
    ];
    final nextEntry = <String, dynamic>{
      'system': hit.tagSystemName,
      'node': hit.tagName,
      'include_descendants': true,
    };
    final dup = maps.any(
      (m) =>
          m['system'] == nextEntry['system'] && m['node'] == nextEntry['node'],
    );
    if (!dup) maps.add(nextEntry);
    final ing = current?.ingredientFilters;
    final nextFilter = RecipeFilter(
      tagFilters: maps.isEmpty ? null : maps,
      ingredientFilters: ing,
    );
    ref
        .read(recipeListFilterProvider.notifier)
        .setFilter(nextFilter.isEmpty ? null : nextFilter);
  }

  void _mergeIngredientFilter(CookingItemSearchHit hit) {
    final current = ref.read(recipeListFilterProvider);
    final rows = <Map<String, dynamic>>[
      if (current?.ingredientFilters != null) ...current!.ingredientFilters!,
    ];
    final nextEntry = <String, dynamic>{'id': hit.id, 'name': hit.name};
    final dup = rows.any((m) => m['id'] == nextEntry['id']);
    if (!dup) rows.add(nextEntry);
    final tags = current?.tagFilters;
    final nextFilter = RecipeFilter(
      tagFilters: tags,
      ingredientFilters: rows.isEmpty ? null : rows,
    );
    ref
        .read(recipeListFilterProvider.notifier)
        .setFilter(nextFilter.isEmpty ? null : nextFilter);
  }

  Future<void> _openFilterSheet() async {
    try {
      final schema = await ref.read(recipeSchemaViewProvider.future);
      final ingredients = await ref.read(cookingItemsProvider.future);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => RecipeTagFilterSheet(
          schema: schema,
          ingredients: ingredients,
          initial: ref.read(recipeListFilterProvider),
          onApply: (f) {
            ref.read(recipeListFilterProvider.notifier).setFilter(f);
          },
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not load filters')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(recipeListFilterProvider);
    final tagFilters = filter?.tagFilters;
    final ingredientFilters = filter?.ingredientFilters;
    final searchQuery = ref.watch(recipeSearchQueryProvider);
    final searchAsync = ref.watch(recipeSearchResultsProvider);
    final showSearchOverlay = searchQuery.trim().isNotEmpty;

    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.zinc100)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TapRegion(
              groupId: _searchTapGroup,
              onTapOutside: (_) => _clearSearch(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => ref
                        .read(recipeSearchQueryProvider.notifier)
                        .setQuery(v),
                    decoration: InputDecoration(
                      hintText: 'Search recipes...',
                      hintStyle: const TextStyle(
                        color: AppColors.zinc400,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: const Icon(
                        SolarLinearIcons.magnifer,
                        size: 18,
                        color: AppColors.zinc400,
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              tooltip: 'Clear',
                              onPressed: _clearSearch,
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: AppColors.zinc400,
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.zinc50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                    ),
                  ),
                  if (showSearchOverlay) ...[
                    const SizedBox(height: 6),
                    Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: searchAsync.when(
                          data: (list) {
                            if (list == null) {
                              return const SizedBox.shrink();
                            }
                            if (list.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Text(
                                  'No matches',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.zinc500,
                                  ),
                                ),
                              );
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: list.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: AppColors.zinc100,
                              ),
                              itemBuilder: (context, i) {
                                final item = list[i];
                                switch (item) {
                                  case RecipeSearchHit(:final id, :final name):
                                    return ListTile(
                                      dense: true,
                                      title: Text(
                                        name,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.zinc900,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Recipe',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.zinc500,
                                        ),
                                      ),
                                      onTap: () {
                                        _clearSearch();
                                        context.push('/recipe/$id');
                                      },
                                    );
                                  case CookingItemSearchHit hit:
                                    return ListTile(
                                      dense: true,
                                      title: Text(
                                        hit.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.zinc900,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Ingredient · tap to filter',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.zinc500,
                                        ),
                                      ),
                                      onTap: () {
                                        _mergeIngredientFilter(hit);
                                        _clearSearch();
                                      },
                                    );
                                  case final TagSearchHit tag:
                                    return ListTile(
                                      dense: true,
                                      title: Text(
                                        tag.tagName,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.zinc900,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${tag.tagSystemName} · Tag',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.zinc500,
                                        ),
                                      ),
                                      onTap: () {
                                        _mergeTagFilter(tag);
                                        _clearSearch();
                                      },
                                    );
                                }
                              },
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.orange500,
                                ),
                              ),
                            ),
                          ),
                          error: (e, _) => Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              'Search failed',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.zinc500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final async = ref.watch(recipeListProvider);
                    final n = async.maybeWhen(
                      data: (list) => list.length,
                      orElse: () => 0,
                    );
                    return Text(
                      '$n recipes',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: AppColors.zinc500,
                      ),
                    );
                  },
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _openFilterSheet,
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.zinc500,
                        padding: const EdgeInsets.all(4),
                        minimumSize: const Size(32, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.filter_list, size: 20),
                      tooltip: 'Filter recipes',
                    ),
                    TextButton.icon(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.zinc500,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(
                        SolarLinearIcons.sortFromTopToBottom,
                        size: 14,
                      ),
                      label: const Text(
                        'Recent',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if ((tagFilters != null && tagFilters.isNotEmpty) ||
                (ingredientFilters != null &&
                    ingredientFilters.isNotEmpty)) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 30,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (tagFilters != null)
                      for (var i = 0; i < tagFilters.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _FilterTagChip(
                            label: tagFilterLabel(tagFilters[i]),
                            onRemove: () {
                              final nextTags = List<Map<String, dynamic>>.from(
                                tagFilters,
                              )..removeAt(i);
                              final next = RecipeFilter(
                                tagFilters: nextTags.isEmpty ? null : nextTags,
                                ingredientFilters: ingredientFilters,
                              );
                              ref
                                  .read(recipeListFilterProvider.notifier)
                                  .setFilter(next.isEmpty ? null : next);
                            },
                          ),
                        ),
                    if (ingredientFilters != null)
                      for (var j = 0; j < ingredientFilters.length; j++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _FilterTagChip(
                            label: ingredientFilterLabel(ingredientFilters[j]),
                            onRemove: () {
                              final nextIng = List<Map<String, dynamic>>.from(
                                ingredientFilters,
                              )..removeAt(j);
                              final next = RecipeFilter(
                                tagFilters: tagFilters,
                                ingredientFilters: nextIng.isEmpty
                                    ? null
                                    : nextIng,
                              );
                              ref
                                  .read(recipeListFilterProvider.notifier)
                                  .setFilter(next.isEmpty ? null : next);
                            },
                          ),
                        ),
                    TextButton(
                      onPressed: () {
                        ref
                            .read(recipeListFilterProvider.notifier)
                            .setFilter(null);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.zinc400,
                      ),
                      child: Text(
                        'Clear all',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterTagChip extends StatelessWidget {
  const _FilterTagChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.orange50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.orange200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.orange800,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppColors.orange600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onChanged});

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.orange100)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  label: 'Week',
                  icon: SolarLinearIcons.calendar,
                  selected: currentIndex == 0,
                  onTap: () => onChanged(0),
                ),
                _NavItem(
                  label: 'Recipes',
                  icon: SolarLinearIcons.book,
                  selected: currentIndex == 1,
                  onTap: () => onChanged(1),
                ),
                _NavItem(
                  label: 'Buy',
                  icon: SolarLinearIcons.cartLarge,
                  selected: currentIndex == 2,
                  onTap: () => onChanged(2),
                ),
                _NavItem(
                  label: 'Stats',
                  icon: SolarLinearIcons.pieChart,
                  selected: currentIndex == 3,
                  onTap: () => onChanged(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.orange500 : AppColors.zinc400;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.4,
                fontWeight: FontWeight.w500,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
