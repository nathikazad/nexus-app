import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/data/providers.dart';
import 'package:nx_cooking/domain/schema/model_type_view.dart';

/// Tag systems defined on the Recipe model type (KGQL schema).
class TagSystemsScreen extends ConsumerWidget {
  const TagSystemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemaAsync = ref.watch(recipeSchemaViewProvider);

    return schemaAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (schema) {
        final systems = schema.tagSystems;
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 16),
                child: Row(
                  children: [
                    if (context.canPop())
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 40, minHeight: 40),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.zinc500,
                          size: 22,
                        ),
                        onPressed: () => context.pop(),
                      ),
                    Expanded(
                      child: Text(
                        'Tag systems',
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
            const Divider(height: 1, color: AppColors.zinc100),
            Expanded(
              child: ColoredBox(
                color: AppColors.zinc50.withValues(alpha: 0.5),
                child: systems.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _placeholderRow(
                            'Category',
                            'exclusive · tree · 24 nodes',
                          ),
                          _placeholderRow(
                            'Priority',
                            'exclusive · flat · 3 nodes',
                          ),
                          _placeholderRow(
                            'Project',
                            'multiple · flat · 8 nodes',
                          ),
                        ],
                      )
                    : ListView.separated(
                        itemCount: systems.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppColors.zinc100),
                        itemBuilder: (context, i) {
                          final ts = systems[i];
                          return Material(
                            color: Colors.white,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              title: Text(
                                ts.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.zinc900,
                                ),
                              ),
                              subtitle: Text(
                                '${ts.selectionMode} · ${ts.isHierarchical ? "tree" : "flat"} · ${countTagNodes(ts)} nodes',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.zinc400,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: AppColors.zinc300,
                                size: 22,
                              ),
                              onTap: ts.id == null
                                  ? null
                                  : () => context.push('/tag-system/form/${ts.id}'),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );

        return Scaffold(
          backgroundColor: Colors.white,
          body: body,
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.push('/tag-system/form'),
            backgroundColor: AppColors.orange500,
            foregroundColor: Colors.white,
            elevation: 2,
            child: const Icon(Icons.add, size: 28),
          ),
        );
      },
    );
  }

  Widget _placeholderRow(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.zinc900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.zinc400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.zinc300,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
