import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nexus_voice_assistant/app_theme.dart';
import 'package:nexus_voice_assistant/widgets/loading_indicator.dart';
import 'package:nexus_voice_assistant/widgets/error_widget.dart';
import 'package:nexus_voice_assistant/screens/navigator/widgets/model_type_row.dart';
import 'package:nexus_voice_assistant/widgets/expanding_fab_menu.dart';

class NavigatorHomeScreen extends ConsumerStatefulWidget {
  const NavigatorHomeScreen({super.key});

  @override
  ConsumerState<NavigatorHomeScreen> createState() => _NavigatorHomeScreenState();
}

class _NavigatorHomeScreenState extends ConsumerState<NavigatorHomeScreen> {
  // Track which model types are expanded (by ID)
  final Set<int> _expandedIds = {};
  bool _menuOpen = false;

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

  @override
  Widget build(BuildContext context) {
    final modelTypesAsync = ref.watch(modelTypesProvider);
    final paddingTop = MediaQuery.paddingOf(context).top;

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
              title: const Text('Model Types'),
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

              // Helper function to build list items recursively
              List<Widget> buildModelTypeItems(List<ModelType> types, {int indentLevel = 0}) {
                final items = <Widget>[];
                for (var modelType in types) {
                  final hasChildren = modelType.children != null && modelType.children!.isNotEmpty;
                  final isExpanded = _expandedIds.contains(modelType.id);
                  
                  // Add the model type itself
                  items.add(
                    Padding(
                      padding: EdgeInsets.only(left: indentLevel * 32.0),
                        child: ModelTypeRow(
                          modelType: modelType,
                        showExpandButton: hasChildren,
                        isExpanded: isExpanded,
                        onExpandTap: hasChildren ? () => _toggleExpand(modelType.id) : null,
                        onTap: () {
                          // Navigate to models list for base types, settings for others
                          if (modelType.typeKind == 'base') {
                            context.push('/models/${modelType.id}');
                          } else {
                            context.push('/model-type-settings/${modelType.id}');
                          }
                        },
                          onSettingsTap: () async {
                            final result = await context.push('/model-type-form?modelTypeId=${modelType.id}');
                            // If model type was updated successfully, refetch model types
                            if (result == true) {
                              ref.invalidate(modelTypesProvider);
                            }
                          },
                        ),
                  ),
                );
                  
                  // Add children recursively with increased indent (only if expanded)
                  if (hasChildren && isExpanded) {
                    items.addAll(buildModelTypeItems(modelType.children!, indentLevel: indentLevel + 1));
                  }
                }
                return items;
              }

              // Build all items recursively
              final allItems = buildModelTypeItems(modelTypes);

              // Simple ListView for all screen sizes
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(modelTypesProvider);
                  },
                child: ListView(
                    padding: const EdgeInsets.all(16),
                  children: allItems,
                              ),
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
            floatingActionButton: ExpandingFabMenu(
              onModelTypeTap: () async {
                final result = await context.push('/model-type-form');
                // If model type was created/updated successfully, refetch model types
                if (result == true) {
                  ref.invalidate(modelTypesProvider);
                }
              },
              onModelTap: () {
                // TODO: Navigate to model form when route is available
                // context.push('/model-form');
              },
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

