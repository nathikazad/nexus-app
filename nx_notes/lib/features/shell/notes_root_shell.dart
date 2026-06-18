import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_notes/core/layout/is_desktop_layout.dart';
import 'package:nx_notes/data/document/nx_docs_state.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/features/desktop/desktop_shell.dart';
import 'package:nx_notes/features/mobile/mobile_shell.dart';
import 'package:nx_notes/features/shell/notes_state.dart';

class NotesRootShell extends ConsumerStatefulWidget {
  const NotesRootShell({super.key, this.initialDocumentId});

  final int? initialDocumentId;

  @override
  ConsumerState<NotesRootShell> createState() => _NotesRootShellState();
}

class _NotesRootShellState extends ConsumerState<NotesRootShell> {
  int? _bootstrappedRouteDocumentId;
  int? _lastPersistedDocumentId;
  bool? _bootstrappedRouteWasDesktop;
  bool _restoreStarted = false;
  bool _suppressNextPlainRestore = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(
      desktopWorkspaceProvider.select((state) => state.activeDocumentId),
      (_, next) => _handleActiveDocumentChange(next),
    );
    ref.listen<int?>(
      mobileNotesProvider.select((state) => state.activeDocumentId),
      (_, next) => _handleActiveDocumentChange(next),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = isDesktopLayoutWidth(constraints.maxWidth);
        _scheduleBootstrap(isDesktop: isDesktop);
        if (isDesktop) {
          return const DesktopShell();
        }
        return const MobileShell();
      },
    );
  }

  void _scheduleBootstrap({required bool isDesktop}) {
    final routeDocumentId = widget.initialDocumentId;
    if (routeDocumentId != null && routeDocumentId > 0) {
      if (_bootstrappedRouteDocumentId == routeDocumentId &&
          _bootstrappedRouteWasDesktop == isDesktop) {
        return;
      }
      _bootstrappedRouteDocumentId = routeDocumentId;
      _bootstrappedRouteWasDesktop = isDesktop;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openDocument(routeDocumentId, isDesktop: isDesktop);
        _persistLastDocument(routeDocumentId);
      });
      return;
    }

    _bootstrappedRouteDocumentId = null;
    _bootstrappedRouteWasDesktop = null;
    if (_suppressNextPlainRestore) {
      _suppressNextPlainRestore = false;
      _restoreStarted = true;
      return;
    }
    if (_restoreStarted) {
      return;
    }
    _restoreStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreLastDocument());
  }

  void _openDocument(int documentId, {required bool isDesktop}) {
    if (isDesktop) {
      ref.read(desktopWorkspaceProvider.notifier).openDocument(documentId);
    } else {
      ref.read(mobileNotesProvider.notifier).openDocument(documentId);
    }
  }

  void _handleActiveDocumentChange(int? documentId) {
    if (!mounted) {
      return;
    }
    if (documentId == null) {
      if (widget.initialDocumentId != null) {
        _suppressNextPlainRestore = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/docs');
        });
      }
      return;
    }
    if (widget.initialDocumentId != documentId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/docs/$documentId');
      });
    }
    _persistLastDocument(documentId);
  }

  Future<void> _restoreLastDocument() async {
    if (!mounted || widget.initialDocumentId != null) {
      return;
    }
    final service = ref.read(nxDocsStateServiceProvider);
    if (service == null) {
      return;
    }
    try {
      final documentId = await service.loadLastDocumentId();
      if (!mounted || widget.initialDocumentId != null || documentId == null) {
        return;
      }
      context.go('/docs/$documentId');
    } catch (error) {
      debugNxDocsState('restore skipped: $error');
    }
  }

  void _persistLastDocument(int documentId) {
    if (_lastPersistedDocumentId == documentId) {
      return;
    }
    _lastPersistedDocumentId = documentId;
    final service = ref.read(nxDocsStateServiceProvider);
    if (service == null) {
      return;
    }
    unawaited(
      service.saveLastDocumentId(documentId).catchError((Object error) {
        debugNxDocsState('save skipped for document=$documentId: $error');
      }),
    );
  }
}
