import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_voice_assistant/core/theme/app_theme.dart';
import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nx_db/riverpod.dart' show modelTypesProvider;
import 'package:nexus_voice_assistant/domain/schema/schema_model_type.dart';
import 'package:nexus_voice_assistant/core/widgets/error_widget.dart';
import 'package:nexus_voice_assistant/core/widgets/loading_indicator.dart';
import 'package:nexus_voice_assistant/features/schema_navigator/widgets/model_type_tree_row.dart';

SchemaModelType _modelTypeWithChildren(
  SchemaModelType n,
  List<SchemaModelType> children,
) {
  return SchemaModelType(
    id: n.id,
    name: n.name,
    typeKind: n.typeKind,
    description: n.description,
    parentId: n.parentId,
    userId: n.userId,
    parent: n.parent,
    children: children,
    traits: n.traits,
    attributes: n.attributes,
    relations: n.relations,
    tagSystems: n.tagSystems,
  );
}

List<SchemaModelType> _filterModelTypeTree(
  List<SchemaModelType> roots,
  String query,
) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return roots;
  final q = trimmed.toLowerCase();

  List<SchemaModelType> walk(List<SchemaModelType> nodes) {
    final out = <SchemaModelType>[];
    for (final n in nodes) {
      final childFiltered =
          n.children != null ? walk(n.children!) : <SchemaModelType>[];
      final selfMatch = n.name.toLowerCase().contains(q);
      if (selfMatch) {
        out.add(n);
      } else if (childFiltered.isNotEmpty) {
        out.add(_modelTypeWithChildren(n, childFiltered));
      }
    }
    return out;
  }

  return walk(roots);
}

void _collectExpandableIds(List<SchemaModelType> nodes, Set<int> into) {
  for (final n in nodes) {
    if (n.children != null && n.children!.isNotEmpty) {
      into.add(n.id);
      _collectExpandableIds(n.children!, into);
    }
  }
}

class ModelsPage extends ConsumerStatefulWidget {
  const ModelsPage({super.key});

  @override
  ConsumerState<ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends ConsumerState<ModelsPage> {
  final Set<int> _expandedIds = {};
  bool _menuOpen = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openPreferences() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Preferences'),
            surfaceTintColor: Colors.transparent,
          ),
          body: Center(
            child: Text(
              'Preferences coming soon',
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.gray500),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
  }

  void _toggleExpand(int modelTypeId) {
    setState(() {
      if (_expandedIds.contains(modelTypeId)) {
        _expandedIds.remove(modelTypeId);
      } else {
        _expandedIds.add(modelTypeId);
      }
    });
  }

  List<Widget> _buildModelTypeItems(
    List<SchemaModelType> types, {
    int indentLevel = 0,
  }) {
    final items = <Widget>[];
    for (var i = 0; i < types.length; i++) {
      final modelType = types[i];
      final hasChildren = modelType.children != null && modelType.children!.isNotEmpty;
      final isExpanded = _expandedIds.contains(modelType.id);
      final showTopDivider = indentLevel == 0 && i > 0;

      items.add(
        ModelTypeTreeRow(
          modelType: modelType,
          isGroupHeader: hasChildren,
          indentLevel: indentLevel,
          isExpanded: isExpanded,
          showTopDivider: showTopDivider,
          onTap: () {
            if (hasChildren) {
              _toggleExpand(modelType.id);
            } else {
              context.push('/model-type/${modelType.id}');
            }
          },
        ),
      );

      if (hasChildren && isExpanded) {
        items.addAll(
          _buildModelTypeItems(
            modelType.children!,
            indentLevel: indentLevel + 1,
          ),
        );
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final modelTypesAsync = ref.watch(schemaModelTypesProvider);
    final paddingTop = MediaQuery.paddingOf(context).top;
    final searchQuery = _searchController.text;

    return PopScope(
      canPop: !_menuOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _menuOpen) {
          setState(() => _menuOpen = false);
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text('Models'),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              actions: [
                Tooltip(
                  message: 'Menu',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _menuOpen = !_menuOpen),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Icons.menu, color: AppColors.gray600, size: 24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                return modelTypesAsync.when(
                  data: (modelTypes) {
                    if (modelTypes.isEmpty) {
                      return const Center(
                        child: Text('No model types found'),
                      );
                    }

                    final filtered = _filterModelTypeTree(modelTypes, searchQuery);
                    if (searchQuery.trim().isNotEmpty) {
                      final need = <int>{};
                      _collectExpandableIds(filtered, need);
                      final missing = need.difference(_expandedIds);
                      if (missing.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() => _expandedIds.addAll(missing));
                        });
                      }
                    }

                    final allItems = _buildModelTypeItems(filtered);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.gray900,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Search types...',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.gray400,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                size: 20,
                                color: AppColors.gray400,
                              ),
                              suffixIcon: searchQuery.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear',
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                        FocusScope.of(context).unfocus();
                                      },
                                      icon: Icon(
                                        Icons.close,
                                        size: 20,
                                        color: AppColors.gray400,
                                      ),
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: AppColors.gray100,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(modelTypesProvider);
                            },
                            child: ListView(
                              padding: const EdgeInsets.only(bottom: 96),
                              children: allItems,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const LoadingIndicator(),
                  error: (error, stack) => ErrorDisplay(
                    message: error.toString(),
                    onRetry: () {
                      ref.invalidate(modelTypesProvider);
                    },
                  ),
                );
              },
            ),
            floatingActionButton: FloatingActionButton(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onPressed: () async {
                final result = await context.push<bool>('/model-type-form');
                if (result == true) {
                  ref.invalidate(modelTypesProvider);
                }
              },
              child: const Icon(Icons.add),
            ),
          ),
          if (_menuOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _menuOpen = false),
                behavior: HitTestBehavior.opaque,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.32),
                ),
              ),
            ),
            Positioned(
              top: paddingTop + kToolbarHeight + 4,
              right: 20,
              width: 220,
              child: Material(
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gray100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        onTap: () {
                          setState(() => _menuOpen = false);
                          _openPreferences();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.settings_outlined,
                                size: 18,
                                color: AppColors.gray500,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Preferences',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.gray900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.gray100,
                        ),
                      ),
                      InkWell(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(12),
                        ),
                        onTap: () async {
                          setState(() => _menuOpen = false);
                          await _logout();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                size: 18,
                                color: AppColors.gray500,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Log out',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.gray900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
