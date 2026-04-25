import 'package:flutter/material.dart';

import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/data/fake/seed_data.dart';

/// Sticky day header (`reference/desktop` `.dd-head`).
class DdHead extends StatelessWidget {
  const DdHead({
    super.key,
    required this.dailyDate,
    required this.onPrev,
    required this.onNext,
    this.onBack,
  });

  final DateTime dailyDate;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final ymd = formatYmd(dailyDate);
    final cmp = ymd.compareTo(kReferenceTodayYmd);
    final pill = cmp == 0
        ? _PillKind.today
        : cmp < 0
            ? _PillKind.past
            : _PillKind.future;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(blurRadius: 24, offset: Offset(0, 4), color: Color(0x40000000))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (onBack != null)
                OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.muted,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: const Text('Back', style: TextStyle(fontSize: 12)),
                ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(999),
                  color: AppColors.panel2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ArrowBtn(icon: Icons.chevron_left, onPressed: onPrev),
                    Container(width: 1, height: 28, color: AppColors.border),
                    _ArrowBtn(icon: Icons.chevron_right, onPressed: onNext),
                  ],
                ),
              ),
              Text(
                longDowLabel(dailyDate),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text),
              ),
              _DdPill(kind: pill),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            fullDateLine(dailyDate),
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

enum _PillKind { today, past, future }

class _DdPill extends StatelessWidget {
  const _DdPill({required this.kind});

  final _PillKind kind;

  @override
  Widget build(BuildContext context) {
    final (text, bg, border, fg) = switch (kind) {
      _PillKind.today => (
          'TODAY',
          AppColors.accentSoft,
          const Color(0x596AA3FF),
          AppColors.accent,
        ),
      _PillKind.past => (
          'PAST',
          AppColors.panel3,
          AppColors.border,
          AppColors.dim,
        ),
      _PillKind.future => (
          'FUTURE',
          const Color(0x26FBBF24),
          const Color(0x59FBBF24),
          AppColors.warn,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.7,
          color: fg,
        ),
      ),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  const _ArrowBtn({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: AppColors.text),
        ),
      ),
    );
  }
}
