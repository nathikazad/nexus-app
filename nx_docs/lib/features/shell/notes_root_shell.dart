import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_docs/core/layout/is_desktop_layout.dart';
import 'package:nx_docs/data/document/nx_docs_state.dart';
import 'package:nx_docs/data/providers.dart';
import 'package:nx_docs/composition/offline_providers.dart';
import 'package:nx_docs/features/desktop/desktop_shell.dart';
import 'package:nx_docs/features/live_conversation/note_live_conversation_coordinator.dart';
import 'package:nx_docs/features/mobile/mobile_shell.dart';
import 'package:nx_docs/features/shell/notes_state.dart';

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

  @override
  Widget build(BuildContext context) {
    ref.watch(noteLiveConversationCoordinatorProvider);
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

  void _persistLastDocument(int documentId) {
    if (_lastPersistedDocumentId == documentId) {
      return;
    }
    _lastPersistedDocumentId = documentId;
    unawaited(_persistLastDocumentToStores(documentId));
  }

  Future<void> _persistLastDocumentToStores(int documentId) async {
    final session = await ref.read(activeOfflineSessionProvider.future);
    if (session != null) {
      final localStore = await ref.read(lastOpenedDocumentStoreProvider.future);
      await localStore.save(session.accountKey, documentId);
    }

    final cloudService = ref.read(nxDocsStateServiceProvider);
    if (cloudService == null) return;
    try {
      await cloudService.saveLastDocumentId(documentId);
    } catch (error) {
      debugNxDocsState('cloud save skipped for document=$documentId: $error');
    }
  }
}
