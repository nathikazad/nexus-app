import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/nx_db.dart';

import '../../app_theme.dart';
import '../../desktop/desktop_nav.dart';
import '../../util/expense_schema.dart';
import '../../providers/expense_providers.dart';
import '../../layout.dart';

/// Reference Screen 6: Tag Systems.
class TagSystemsScreen extends ConsumerWidget {
  const TagSystemsScreen({super.key, this.embedded = false});

  /// When true (desktop shell left pane): no [Scaffold], no FAB — shell provides FAB.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemaAsync = ref.watch(expenseSchemaProvider);

    return schemaAsync.when(
      loading: () => embedded
          ? const ColoredBox(
              color: Colors.white,
              child: Center(child: CircularProgressIndicator()),
            )
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => embedded
          ? ColoredBox(
              color: Colors.white,
              child: Center(child: Text('$e')),
            )
          : Scaffold(body: Center(child: Text('$e'))),
      data: (schema) {
        final systems = schema.tagSystems ?? const <TagSystem>[];
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!embedded)
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    RefLayout.px5,
                    RefLayout.appBarTop,
                    RefLayout.px5,
                    RefLayout.pb4,
                  ),
                  child: Row(
                    children: [
                      if (context.canPop())
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          icon: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 22),
                          onPressed: () => context.pop(),
                        ),
                      Expanded(child: Text('Tag systems', style: refAppBarTitleLarge())),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  RefLayout.px5,
                  RefLayout.appBarTop,
                  RefLayout.px5,
                  RefLayout.pb4,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('Tag systems', style: refAppBarTitleLarge())),
                  ],
                ),
              ),
            const Divider(height: 1, color: AppColors.slate100),
            Expanded(
              child: ColoredBox(
                color: AppColors.slate50.withValues(alpha: 0.5),
                child: systems.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(RefLayout.px5),
                        children: [
                          _placeholderRow('Category', 'exclusive · tree · 24 nodes'),
                          _placeholderRow('Priority', 'exclusive · flat · 3 nodes'),
                          _placeholderRow('Project', 'multiple · flat · 8 nodes'),
                        ],
                      )
                    : ListView.separated(
                        itemCount: systems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.slate100),
                        itemBuilder: (context, i) {
                          final ts = systems[i];
                          return Material(
                            color: Colors.white,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: RefLayout.px5, vertical: 8),
                              title: Text(
                                ts.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.slate900,
                                ),
                              ),
                              subtitle: Text(
                                '${ts.selectionMode} · ${ts.isHierarchical ? "tree" : "flat"} · ${countTagNodes(ts)} nodes',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.slate400,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right, color: AppColors.slate300, size: 22),
                              onTap: () => navToTagSystemEdit(context, ref, ts.id),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );

        if (embedded) {
          return ColoredBox(color: Colors.white, child: body);
        }

        return Scaffold(
          backgroundColor: Colors.white,
          body: body,
          floatingActionButton: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: refFabShadow),
            child: FloatingActionButton(
              onPressed: () => navToTagSystemCreate(context, ref),
              backgroundColor: AppColors.teal600,
              foregroundColor: Colors.white,
              elevation: 0,
              child: const Icon(Icons.add_circle_outline, size: 28),
            ),
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
          padding: const EdgeInsets.symmetric(horizontal: RefLayout.px5, vertical: 16),
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
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.slate300, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
