import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_docs/account/account_providers.dart';
import 'package:nx_docs/documents/document_providers.dart';
import 'package:nx_docs/library/library_providers.dart';
import 'package:nx_docs/app/theme.dart';
import 'package:nx_docs/documents/document_data_providers.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/tags/tag_system.dart';
import 'package:nx_docs/documents/document_actions.dart';
import 'package:nx_docs/companion/note_companion.dart';
import 'package:nx_docs/books/book_shelf.dart';
import 'package:nx_docs/documents/editor/document_editor_view.dart';
import 'package:nx_docs/library/document_row.dart';
import 'package:nx_docs/settings/settings_button.dart';
import 'package:nx_docs/workspace/workspace_state.dart';

part 'desktop_sidebar.dart';
part 'sidebar_documents.dart';
part 'sidebar_books.dart';
part 'sidebar_sections.dart';
part 'desktop_editor_workspace.dart';
part 'desktop_inspector.dart';
part 'inspector_actions.dart';
part 'inspector_components.dart';
part 'desktop_inspector_links.dart';
part 'desktop_inspector_tags.dart';
part 'desktop_inspector_history.dart';
part 'desktop_result_overlay.dart';

const double _sidebarWidth = 256;
const double _collapsedSidebarWidth = 44;
const double _inspectorWidth = 288;
const double _collapsedInspectorWidth = 44;

class DesktopWorkspace extends ConsumerWidget {
  const DesktopWorkspace({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(desktopWorkspaceProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: <Widget>[
          Row(
            children: <Widget>[
              if (workspace.sidebarCollapsed)
                const SizedBox(
                  width: _collapsedSidebarWidth,
                  child: _CollapsedSidebar(),
                )
              else
                const SizedBox(width: _sidebarWidth, child: _DesktopSidebar()),
              Expanded(child: _DesktopEditorWorkspace(workspace: workspace)),
              if (workspace.inspectorCollapsed)
                const SizedBox(
                  width: _collapsedInspectorWidth,
                  child: _CollapsedInspector(),
                )
              else
                SizedBox(
                  width: _inspectorWidth,
                  child: _DesktopInspector(
                    documentId: workspace.activeDocumentId,
                  ),
                ),
            ],
          ),
          if (workspace.hasOverlay) _DesktopResultOverlay(workspace: workspace),
        ],
      ),
    );
  }
}
