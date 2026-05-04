import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/domain/essay/essay.dart';
import 'package:nx_notes/domain/essay/essay_result_context.dart';

class EssayEditorView extends ConsumerWidget {
  const EssayEditorView({
    required this.essayId,
    this.contextBar,
    this.onTitleChanged,
    super.key,
  });

  final int essayId;
  final Widget? contextBar;
  final ValueChanged<String>? onTitleChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEssay = ref.watch(essayByIdProvider(essayId));
    return asyncEssay.when(
      data: (essay) {
        if (essay == null) {
          return const Center(child: Text('Essay not found'));
        }
        return EssayEditorBody(
          essay: essay,
          contextBar: contextBar,
          onTitleChanged: onTitleChanged,
        );
      },
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class EssayEditorBody extends ConsumerWidget {
  const EssayEditorBody({
    required this.essay,
    this.contextBar,
    this.onTitleChanged,
    super.key,
  });

  final Essay essay;
  final Widget? contextBar;
  final ValueChanged<String>? onTitleChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 700 ? 30.0 : 38.0;
    return Column(
      children: <Widget>[
        if (contextBar != null) contextBar!,
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 54, 48, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      key: ValueKey<int>(essay.id),
                      initialValue: essay.title,
                      onChanged: onTitleChanged,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: titleSize,
                        fontWeight: FontWeight.w600,
                        height: 1.16,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Expanded(
                      child: NxAppFlowyEditor(
                        essay: essay,
                        onChanged: (updated) async {
                          await ref
                              .read(essayRepositoryProvider)
                              .updateDraft(updated);
                          ref.invalidate(essayByIdProvider(essay.id));
                          ref.invalidate(recentEssaysProvider);
                          ref.invalidate(pinnedEssaysProvider);
                          ref.invalidate(tagSystemsProvider);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class NxAppFlowyEditor extends StatefulWidget {
  const NxAppFlowyEditor({
    required this.essay,
    required this.onChanged,
    super.key,
  });

  final Essay essay;
  final Future<void> Function(Essay essay) onChanged;

  @override
  State<NxAppFlowyEditor> createState() => _NxAppFlowyEditorState();
}

class _NxAppFlowyEditorState extends State<NxAppFlowyEditor> {
  late EditorState _editorState;
  late EditorScrollController _scrollController;
  StreamSubscription<EditorTransactionValue>? _transactionSubscription;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _createEditor();
  }

  @override
  void didUpdateWidget(covariant NxAppFlowyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.essay.id != widget.essay.id) {
      _disposeEditor();
      _createEditor();
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _disposeEditor();
    super.dispose();
  }

  void _createEditor() {
    _editorState = EditorState(document: _documentFromEssay(widget.essay));
    _scrollController = EditorScrollController(
      editorState: _editorState,
      shrinkWrap: false,
    );
    _transactionSubscription = _editorState.transactionStream.listen((event) {
      final (time, transaction, options) = event;
      if (time == TransactionTime.after &&
          !options.inMemoryUpdate &&
          transaction.operations.isNotEmpty) {
        _scheduleSave();
      }
    });
  }

  void _disposeEditor() {
    _transactionSubscription?.cancel();
    _scrollController.dispose();
    _editorState.dispose();
  }

  Document _documentFromEssay(Essay essay) {
    if (essay.jsonDocument['format'] == 'appflowy_document') {
      final documentJson = essay.jsonDocument['document'];
      if (documentJson is Map) {
        return Document.fromJson(<String, dynamic>{
          'document': Map<String, dynamic>.from(documentJson),
        });
      }
    }

    if (essay.document.trim().isNotEmpty) {
      return markdownToDocument(essay.document);
    }

    return Document.blank(withInitialText: true);
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 450), () {
      final plainText = _documentPlainText(_editorState.document).trimRight();
      widget.onChanged(
        widget.essay.copyWith(
          document: plainText,
          jsonDocument: <String, dynamic>{
            ...widget.essay.jsonDocument,
            'format': 'appflowy_document',
            'document': _editorState.document.toJson()['document'],
          },
          wordCount: _countWords(plainText),
          excerpt: _excerptFrom(plainText),
        ),
      );
    });
  }

  String _documentPlainText(Document document) {
    final buffer = StringBuffer();
    void visit(Node node) {
      final text = node.delta?.toPlainText();
      if (text != null && text.isNotEmpty) {
        if (buffer.isNotEmpty) {
          buffer.writeln();
        }
        buffer.write(text);
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    for (final child in document.root.children) {
      visit(child);
    }
    return buffer.toString();
  }

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    return RegExp(r'\S+').allMatches(trimmed).length;
  }

  String _excerptFrom(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= 140) {
      return normalized;
    }
    return '${normalized.substring(0, 137)}...';
  }

  @override
  Widget build(BuildContext context) {
    return AppFlowyEditor(
      editorState: _editorState,
      editorScrollController: _scrollController,
      editorStyle: _editorStyle,
      characterShortcutEvents: standardCharacterShortcutEvents,
      commandShortcutEvents: standardCommandShortcutEvents,
      footer: const SizedBox(height: 120),
    );
  }
}

const _editorStyle = EditorStyle.desktop(
  cursorColor: AppColors.text,
  selectionColor: Color(0x333B82F6),
  padding: EdgeInsets.zero,
  maxWidth: 700,
  textStyleConfiguration: TextStyleConfiguration(
    text: TextStyle(color: Color(0xff3f3f46), fontSize: 16, height: 1.62),
    bold: TextStyle(fontWeight: FontWeight.w700),
    italic: TextStyle(fontStyle: FontStyle.italic),
    underline: TextStyle(decoration: TextDecoration.underline),
    strikethrough: TextStyle(decoration: TextDecoration.lineThrough),
    href: TextStyle(
      color: AppColors.blue,
      decoration: TextDecoration.underline,
    ),
    code: TextStyle(
      color: AppColors.text,
      backgroundColor: AppColors.subtle,
      fontFamily: 'monospace',
    ),
    lineHeight: 1.62,
  ),
);

class EditorContextBar extends StatelessWidget {
  const EditorContextBar({
    required this.resultContext,
    required this.activeEssayId,
    required this.onBack,
    required this.onClear,
    super.key,
  });

  final EssayResultContext resultContext;
  final int activeEssayId;
  final VoidCallback onBack;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final index = resultContext.resultIds.indexOf(activeEssayId);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: <Widget>[
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.muted,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text('Back to ${resultContext.title}'),
          ),
          const Spacer(),
          Text(
            '${index + 1} of ${resultContext.resultIds.length}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 16, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
