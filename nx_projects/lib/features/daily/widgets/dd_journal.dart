import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';

class DdJournal extends StatefulWidget {
  const DdJournal({super.key});

  @override
  State<DdJournal> createState() => _DdJournalState();
}

class _DdJournalState extends State<DdJournal> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(offset: Offset(0, 2), blurRadius: 12, color: Color(0x1F000000))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'JOURNAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.muted,
                ),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Divider(color: AppColors.border),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            maxLines: 8,
            minLines: 4,
            style: const TextStyle(color: AppColors.text, fontSize: 14, height: 1.5),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.panel2,
              hintText: "Today’s reflection, notes, or end-of-day thoughts…",
              hintStyle: const TextStyle(color: AppColors.dim, fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.accent, width: 1),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }
}
