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

class EssayEditorBody extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 700 ? 30.0 : 38.0;
    final bodySize = width < 700 ? 14.0 : 16.0;
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        if (contextBar != null) contextBar!,
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 54, 48, 140),
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
                  Text(
                    essay.document,
                    style: TextStyle(
                      fontSize: bodySize,
                      height: 1.62,
                      color: const Color(0xff3f3f46),
                    ),
                  ),
                  const SizedBox(height: 28),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.subtle,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Text(
                        'Super Editor surface placeholder',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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
