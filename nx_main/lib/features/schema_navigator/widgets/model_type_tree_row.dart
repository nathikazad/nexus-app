import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_voice_assistant/core/theme/app_theme.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model_type.dart';

/// Single row in the model type tree (see reference/navigator/model-types.html).
class ModelTypeTreeRow extends StatelessWidget {
  const ModelTypeTreeRow({
    super.key,
    required this.modelType,
    required this.isGroupHeader,
    required this.indentLevel,
    this.isExpanded = false,
    this.onTap,
    this.showTopDivider = false,
  });

  final SchemaModelType modelType;
  final bool isGroupHeader;
  final int indentLevel;
  final bool isExpanded;
  final VoidCallback? onTap;
  final bool showTopDivider;

  static const _orange500 = Color(0xFFF97316);
  static const _orange400 = Color(0xFFFB923C);

  @override
  Widget build(BuildContext context) {
    final leftInset = indentLevel * 32.0;
    final badgeLabel = modelType.typeKind ?? (isGroupHeader ? 'abstract' : 'base');
    final folderColor =
        modelType.typeKind == 'abstract' ? _orange500 : AppColors.gray400;

    return Padding(
      padding: EdgeInsets.only(left: leftInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTopDivider)
            const Divider(height: 1, thickness: 1, color: AppColors.gray100),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    if (isGroupHeader) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          isExpanded ? Icons.expand_more : Icons.chevron_right,
                          size: 18,
                          color: AppColors.gray400,
                        ),
                      ),
                      Icon(Icons.folder_outlined, size: 22, color: folderColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          modelType.name,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.gray900,
                          ),
                        ),
                      ),
                    ] else ...[
                      if (indentLevel > 0) ...[
                        Container(
                          width: 24,
                          height: 1,
                          margin: const EdgeInsets.only(right: 8),
                          color: AppColors.gray200,
                        ),
                      ],
                      Icon(Icons.crop_square_rounded, size: 18, color: _orange400),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          modelType.name,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: AppColors.gray900,
                          ),
                        ),
                      ),
                    ],
                    _kindBadge(badgeLabel),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kindBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: AppColors.gray400,
        ),
      ),
    );
  }
}
