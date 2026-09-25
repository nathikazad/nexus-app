part of 'document_editor_view.dart';

extension _MobileEditorSurface on _NxAppFlowyEditorState {
  Widget _mobileEditorSurface(Widget editor) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          Expanded(child: editor),
          ValueListenableBuilder<Selection?>(
            valueListenable: _editorState.selectionNotifier,
            builder: (context, selection, _) {
              if (selection == null || !widget.active) {
                return const SizedBox.shrink();
              }
              // Scaffold already resizes above the IME. Dock here rather than
              // relying on a second native keyboard-height observer/overlay.
              return MediaQuery.removeViewInsets(
                context: context,
                removeBottom: true,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * .6,
                  ),
                  child: SingleChildScrollView(
                    child: SafeArea(
                      top: false,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: MobileToolbarTheme(
                          backgroundColor: AppColors.panel,
                          foregroundColor: AppColors.text,
                          iconColor: AppColors.text,
                          primaryColor: AppColors.blue,
                          outlineColor: AppColors.line,
                          itemOutlineColor: AppColors.line.withValues(
                            alpha: .55,
                          ),
                          borderRadius: 12,
                          buttonHeight: 44,
                          itemHighlightColor: AppColors.blue,
                          tabBarSelectedBackgroundColor: AppColors.hover,
                          tabBarSelectedForegroundColor: AppColors.text,
                          child: MobileToolbarWidget(
                            editorState: _editorState,
                            selection: selection,
                            toolbarItems: [
                              MobileToolbarItem.action(
                                itemIconBuilder: (_, _, _) => Tooltip(
                                  message: 'Insert block',
                                  child: Icon(Icons.add, color: AppColors.text),
                                ),
                                actionHandler: (context, state) =>
                                    appendNxDocumentElement(
                                      context,
                                      state,
                                      atSelection: true,
                                      searchLinkableModels:
                                          widget.searchLinkableModels,
                                      createLinkedDocument:
                                          widget.createLinkedDocument!,
                                      onLinkableModelSelected:
                                          widget.onLinkableModelSelected!,
                                      uploadDocumentImage:
                                          widget.uploadDocumentImage,
                                    ),
                              ),
                              textDecorationMobileToolbarItemV2,
                              blocksMobileToolbarItem,
                              linkMobileToolbarItem,
                              buildNxMobileColorItem(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _withScrollIndicator(Widget editorSurface) {
    if (isDesktopLayout(context) || !_documentCanScroll) return editorSurface;
    return Stack(
      children: [
        Positioned.fill(child: editorSurface),
        Positioned.fill(
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 4, 8),
              child: Align(
                alignment: Alignment(1, _documentScrollProgress * 2 - 1),
                child: Container(
                  key: const ValueKey<String>('document-scroll-position-dot'),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.text.withValues(alpha: 0.38),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
