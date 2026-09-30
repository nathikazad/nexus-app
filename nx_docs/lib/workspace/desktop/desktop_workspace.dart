import 'package:nx_docs/documents/browser/document_browser_session.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_docs/account/account_providers.dart';
import 'package:nx_docs/workspace/layout.dart';
import 'package:nx_docs/documents/document_providers.dart';
import 'package:nx_docs/library/library_providers.dart';
import 'package:nx_docs/app/theme.dart';
import 'package:nx_docs/documents/document_data_providers.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/tags/tag_system.dart';
import 'package:nx_docs/documents/document_actions.dart';
import 'package:nx_docs/documents/editor/document_editor_view.dart';
import 'package:nx_docs/settings/settings_button.dart';
import 'package:nx_docs/workspace/workspace_state.dart';

part 'desktop_sidebar.dart';
part 'sidebar_documents.dart';
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

class DesktopWorkspace extends ConsumerStatefulWidget {
  const DesktopWorkspace({super.key});

  @override
  ConsumerState<DesktopWorkspace> createState() => _DesktopWorkspaceState();
}

class _DesktopWorkspaceState extends ConsumerState<DesktopWorkspace> {
  bool _overlayInspectorOpen = false;
  bool? _wasCompact;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final compact =
        MediaQuery.sizeOf(context).width < kDockedInspectorBreakpoint;
    if (_wasCompact != compact) _overlayInspectorOpen = false;
    _wasCompact = compact;
  }

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < kDockedInspectorBreakpoint;
    final workspace = ref.watch(desktopWorkspaceProvider);
    final browserOpen =
        workspace.activeDocumentId != null &&
        ref.watch(
              documentBrowserSessionProvider(workspace.activeDocumentId!),
            ) !=
            null;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Row(
              children: <Widget>[
                if (workspace.sidebarCollapsed)
                  const SizedBox(
                    width: _collapsedSidebarWidth,
                    child: _CollapsedSidebar(),
                  )
                else
                  const SizedBox(
                    width: _sidebarWidth,
                    child: _DesktopSidebar(),
                  ),
                Expanded(child: _DesktopEditorWorkspace(workspace: workspace)),
                if (browserOpen)
                  const SizedBox.shrink()
                else if (compact)
                  SizedBox(
                    width: _collapsedInspectorWidth,
                    child: _CollapsedInspector(
                      onExpand: () =>
                          setState(() => _overlayInspectorOpen = true),
                    ),
                  )
                else if (workspace.inspectorCollapsed)
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
            if (!browserOpen && compact && _overlayInspectorOpen)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: _inspectorWidth,
                child: Material(
                  elevation: 12,
                  child: _DesktopInspector(
                    documentId: workspace.activeDocumentId,
                    onCollapse: () =>
                        setState(() => _overlayInspectorOpen = false),
                  ),
                ),
              ),
            if (workspace.hasOverlay)
              _DesktopResultOverlay(workspace: workspace),
          ],
        ),
      ),
    );
  }
}

/// The same document actions are available in a sheet when side panels do not fit.
Future<void> showDocumentInspectorSheet(BuildContext context, int documentId) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: _DesktopInspector(
          documentId: documentId,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    ),
  );
}
