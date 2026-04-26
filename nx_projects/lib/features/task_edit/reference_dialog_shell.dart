import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';

/// Centered card matching [reference/desktop/styles.css] `.modal` / `.modal-backdrop`.
class ReferenceDialog extends StatelessWidget {
  const ReferenceDialog({
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: maxH,
        ),
        child: Material(
          color: AppColors.panel,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.border2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close, size: 20),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(28, 28),
                        padding: EdgeInsets.zero,
                        foregroundColor: AppColors.muted,
                        backgroundColor: Colors.transparent,
                        hoverColor: AppColors.panel2,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxH - 140,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: child,
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
  const RefModalActions({
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
        _RefModalSecondaryButton(
          label: cancelLabel,
          onPressed: onCancel,
        ),
        const SizedBox(width: 8),
        _RefModalPrimaryButton(
          label: primaryLabel,
          onPressed: onPrimary,
        ),
      ],
    );
  }
}

class _RefModalSecondaryButton extends StatelessWidget {
  const _RefModalSecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppColors.muted,
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.panel2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}

class _RefModalPrimaryButton extends StatelessWidget {
  const _RefModalPrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppColors.accent),
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Uppercase field label (`.field-label` in ref).
class RefFieldLabel extends StatelessWidget {
  const RefFieldLabel(this.text, {super.key, this.suffixOpt = false});

  final String text;
  final bool suffixOpt;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.muted,
          letterSpacing: 0.04,
          fontWeight: FontWeight.w500,
        ),
        children: [
          TextSpan(text: text),
          if (suffixOpt)
            const TextSpan(
              text: ' (optional)',
              style: TextStyle(
                color: AppColors.dim,
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
InputDecoration refFieldDecoration(String? label, {String? hint, bool isDense = true}) {
  return InputDecoration(
    isDense: isDense,
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.muted, fontSize: 12),
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.dim, fontSize: 13),
    filled: true,
    fillColor: AppColors.panel2,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: AppColors.accent, width: 1),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  );
}
