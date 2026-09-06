import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

/// Formats replies without interpreting the reader's own input as Markdown.
class ReadingCompanionMessage extends StatelessWidget {
  const ReadingCompanionMessage({
    required this.text,
    required this.fromUser,
    super.key,
  });

  final String text;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium!.copyWith(height: 1.5);
    if (fromUser) return SelectableText(text, style: body);

    return MarkdownBody(
      data: text,
      inlineSyntaxes: [_LineBreakSyntax()],
      selectable: true,
      // Replies should never fetch arbitrary remote images automatically.
      imageBuilder: (uri, title, alt) => Text(alt ?? title ?? 'Image'),
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: body,
        strong: const TextStyle(fontWeight: FontWeight.w700),
        em: const TextStyle(fontStyle: FontStyle.italic),
        h1: body.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
        h2: body.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
        h3: body.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        listBullet: body,
        blockSpacing: 12,
        listIndent: 20,
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        code: body.copyWith(fontFamily: 'monospace'),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        tableBody: body,
        tableHead: body.copyWith(fontWeight: FontWeight.w700),
        tableBorder: TableBorder.all(color: theme.colorScheme.outlineVariant),
        tableCellsPadding: const EdgeInsets.all(8),
      ),
    );
  }
}

class _LineBreakSyntax extends md.InlineSyntax {
  _LineBreakSyntax() : super(r'<br\s*/?>', caseSensitive: false);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.empty('br'));
    return true;
  }
}
