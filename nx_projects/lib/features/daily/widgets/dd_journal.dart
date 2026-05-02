import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';

class DdJournal extends StatefulWidget {
  DdJournal({super.key});

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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 2),
            blurRadius: 12,
            color: Color(0x1F000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'JOURNAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: context.colors.muted,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Divider(color: context.colors.border),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          TextField(
            controller: _c,
            maxLines: 8,
            minLines: 4,
            style: TextStyle(
              color: context.colors.text,
              fontSize: 14,
              height: 1.5,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: context.colors.panel2,
              hintText: "Today’s reflection, notes, or end-of-day thoughts…",
              hintStyle: TextStyle(color: context.colors.dim, fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.colors.accent, width: 1),
              ),
              contentPadding: EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }
}
