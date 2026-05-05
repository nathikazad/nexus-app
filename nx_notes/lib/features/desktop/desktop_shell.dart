import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/domain/essay/essay.dart';
import 'package:nx_notes/domain/tags/tag_system.dart';
import 'package:nx_notes/domain/essay/essay_snap.dart';
import 'package:nx_notes/domain/links/linked_model.dart';
import 'package:nx_notes/features/essay/essay_actions.dart';
import 'package:nx_notes/features/editor/essay_editor_view.dart';
import 'package:nx_notes/features/navigator/essay_row.dart';
import 'package:nx_notes/features/shell/notes_state.dart';

part 'desktop_sidebar.dart';
part 'desktop_editor_workspace.dart';
part 'desktop_inspector.dart';
part 'desktop_inspector_links.dart';
part 'desktop_inspector_tags.dart';
part 'desktop_inspector_history.dart';
part 'desktop_result_overlay.dart';

const double _sidebarWidth = 256;
const double _inspectorWidth = 288;

class DesktopShell extends ConsumerWidget {
  const DesktopShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(desktopWorkspaceProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: <Widget>[
          Row(
            children: <Widget>[
              const SizedBox(width: _sidebarWidth, child: _DesktopSidebar()),
              Expanded(child: _DesktopEditorWorkspace(workspace: workspace)),
              SizedBox(
                width: _inspectorWidth,
                child: _DesktopInspector(essayId: workspace.activeEssayId),
              ),
            ],
          ),
          if (workspace.hasOverlay) _DesktopResultOverlay(workspace: workspace),
        ],
      ),
    );
  }
}
