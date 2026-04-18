import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import '../../app_theme.dart';

class ActionColorsPage extends StatefulWidget {
  const ActionColorsPage({super.key});

  @override
  State<ActionColorsPage> createState() => _ActionColorsPageState();
}

class _ActionColorsPageState extends State<ActionColorsPage> {
  final List<_ActionColorItem> _items = [
    const _ActionColorItem(label: 'Sleep', color: AppColors.sleepBlue),
    const _ActionColorItem(label: 'Work', color: Color(0xFF185FA5)),
    const _ActionColorItem(label: 'Yoga', color: AppColors.dotOk),
    const _ActionColorItem(label: 'Eat', color: AppColors.calOrange),
    const _ActionColorItem(label: 'Shopping', color: Color(0xFFD4537E)),
    const _ActionColorItem(label: 'Workout', color: AppColors.calOlive),
    const _ActionColorItem(label: 'Commute', color: Color(0xFF888780)),
    const _ActionColorItem(label: 'Reading', color: Color(0xFFBA7517)),
  ];

  static const List<Color> _swatches = [
    AppColors.sleepBlue,
    Color(0xFF185FA5),
    AppColors.dotOk,
    AppColors.calOrange,
    Color(0xFFD4537E),
    AppColors.calOlive,
    Color(0xFF888780),
    Color(0xFFBA7517),
    AppColors.accent,
    Color(0xFF534AB7),
    Color(0xFF0EA5E9),
    Color(0xFF7C3AED),
    Color(0xFF10B981),
    Color(0xFFE11D48),
    Color(0xFFF59E0B),
    Color(0xFF111827),
  ];

  Future<void> _pickColor(int index) async {
    final selected = await showModalBottomSheet<Color>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final current = _items[index].color;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose color for ${_items[index].label}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _swatches.map((c) {
                    final selectedSwatch = c.toARGB32() == current.toARGB32();
                    return GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(c),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border: Border.all(
                            color: selectedSwatch ? AppColors.slate900 : AppColors.slate200,
                            width: selectedSwatch ? 2.2 : 1.2,
                          ),
                        ),
                        child: selectedSwatch
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) return;
    setState(() {
      _items[index] = _ActionColorItem(label: _items[index].label, color: selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(SolarLinearIcons.arrowLeft, size: 22),
                    color: AppColors.slate600,
                  ),
                  const Expanded(
                    child: Text(
                      'Colors',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.slate100),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Text(
                'Tap a color to choose a new swatch',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.slate500,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.slate100),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.slate900,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _pickColor(index),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.slate200),
                              borderRadius: BorderRadius.circular(999),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: item.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _hex(item.color),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.slate600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  SolarLinearIcons.altArrowDown,
                                  size: 14,
                                  color: AppColors.slate400,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _hex(Color c) {
    final rgb = c.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

class _ActionColorItem {
  const _ActionColorItem({required this.label, required this.color});

  final String label;
  final Color color;
}
