import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';

/// Centered card matching [reference/desktop/styles.css] `.modal` / `.modal-backdrop`.
class ReferenceDialog extends StatelessWidget {
  ReferenceDialog({
    super.key,
    required this.title,
    required this.child,
    required this.onClose,
    required this.onPrimary,
    this.primaryLabel = 'Save',
    this.cancelLabel = 'Cancel',
  });

  final String title;
  final Widget child;
  final VoidCallback onClose;
  final VoidCallback onPrimary;
  final String primaryLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.9;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxH),
        child: Material(
          color: context.colors.panel,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: context.colors.border2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(18, 14, 8, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.colors.text,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: Icon(Icons.close, size: 20),
                      style: IconButton.styleFrom(
                        minimumSize: Size(28, 28),
                        padding: EdgeInsets.zero,
                        foregroundColor: context.colors.muted,
                        backgroundColor: Colors.transparent,
                        hoverColor: context.colors.panel2,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.colors.border),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH - 140),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: child,
                ),
              ),
              Divider(height: 1, color: context.colors.border),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: RefModalActions(
                  cancelLabel: cancelLabel,
                  primaryLabel: primaryLabel,
                  onCancel: onClose,
                  onPrimary: onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Right-aligned primary + secondary actions (`.modal-foot`); shared by dialogs and bottom sheets.
class RefModalActions extends StatelessWidget {
  RefModalActions({
    super.key,
    required this.onCancel,
    required this.onPrimary,
    required this.primaryLabel,
    this.cancelLabel = 'Cancel',
  });

  final VoidCallback onCancel;
  final VoidCallback onPrimary;
  final String primaryLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _RefModalSecondaryButton(label: cancelLabel, onPressed: onCancel),
        SizedBox(width: 8),
        _RefModalPrimaryButton(label: primaryLabel, onPressed: onPrimary),
      ],
    );
  }
}

class _RefModalSecondaryButton extends StatelessWidget {
  _RefModalSecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: context.colors.muted,
        side: BorderSide(color: context.colors.border),
        backgroundColor: context.colors.panel2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _RefModalPrimaryButton extends StatelessWidget {
  _RefModalPrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: context.colors.accent,
        foregroundColor: context.colors.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: context.colors.accent),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Uppercase field label (`.field-label` in ref).
class RefFieldLabel extends StatelessWidget {
  RefFieldLabel(this.text, {super.key, this.suffixOpt = false});

  final String text;
  final bool suffixOpt;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 11,
          color: context.colors.muted,
          letterSpacing: 0.04,
          fontWeight: FontWeight.w500,
        ),
        children: [
          TextSpan(text: text),
          if (suffixOpt)
            TextSpan(
              text: ' (optional)',
              style: TextStyle(
                color: context.colors.dim,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
              ),
            ),
        ],
      ),
    );
  }
}

/// Reference text field / dropdown decoration.
InputDecoration refFieldDecoration(
  BuildContext context,
  String? label, {
  String? hint,
  bool isDense = true,
}) {
  return InputDecoration(
    isDense: isDense,
    labelText: label,
    labelStyle: TextStyle(color: context.colors.muted, fontSize: 12),
    hintText: hint,
    hintStyle: TextStyle(color: context.colors.dim, fontSize: 13),
    filled: true,
    fillColor: context.colors.panel2,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: context.colors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: context.colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: context.colors.accent, width: 1),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  );
}
