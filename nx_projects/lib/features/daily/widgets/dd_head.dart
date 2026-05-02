import 'package:flutter/material.dart';

import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/data/fake/seed_data.dart';

/// Sticky day header (`reference/desktop` `.dd-head`).
class DdHead extends StatelessWidget {
  DdHead({
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
      padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: context.colors.bg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            offset: Offset(0, 4),
            color: Color(0x40000000),
          ),
        ],
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
                    foregroundColor: context.colors.muted,
                    side: BorderSide(color: context.colors.border),
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text('Back', style: TextStyle(fontSize: 12)),
                ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: context.colors.border),
                  borderRadius: BorderRadius.circular(999),
                  color: context.colors.panel2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ArrowBtn(icon: Icons.chevron_left, onPressed: onPrev),
                    Container(
                      width: 1,
                      height: 28,
                      color: context.colors.border,
                    ),
                    _ArrowBtn(icon: Icons.chevron_right, onPressed: onNext),
                  ],
                ),
              ),
              Text(
                longDowLabel(dailyDate),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.colors.text,
                ),
              ),
              _DdPill(kind: pill),
            ],
          ),
          SizedBox(height: 8),
          Text(
            fullDateLine(dailyDate),
            style: TextStyle(fontSize: 13, color: context.colors.muted),
          ),
        ],
      ),
    );
  }
}

enum _PillKind { today, past, future }

class _DdPill extends StatelessWidget {
  _DdPill({required this.kind});

  final _PillKind kind;

  @override
  Widget build(BuildContext context) {
    final (text, bg, border, fg) = switch (kind) {
      _PillKind.today => (
        'TODAY',
        context.colors.accentSoft,
        Color(0x596AA3FF),
        context.colors.accent,
      ),
      _PillKind.past => (
        'PAST',
        context.colors.panel3,
        context.colors.border,
        context.colors.dim,
      ),
      _PillKind.future => (
        'FUTURE',
        Color(0x26FBBF24),
        Color(0x59FBBF24),
        context.colors.warn,
      ),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
  _ArrowBtn({required this.icon, required this.onPressed});

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
          child: Icon(icon, size: 20, color: context.colors.text),
        ),
      ),
    );
  }
}
