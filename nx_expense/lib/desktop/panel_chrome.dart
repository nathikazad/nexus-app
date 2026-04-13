import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../layout.dart';

/// Lightweight header + body for screens embedded in desktop panels (no [Scaffold]).
class PanelChrome extends StatelessWidget {
  const PanelChrome({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.leading,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.slate100)),
          ),
          child: Row(
            children: [
              if (leading != null) leading!,
              Expanded(
                child: Text(
                  title,
                  style: refAppBarTitleBase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...actions,
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}
