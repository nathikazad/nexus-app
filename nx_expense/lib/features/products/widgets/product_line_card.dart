import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_expense/core/formatting/format.dart';
import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/suggestion/suggestion_api.dart';

class ProductLineCard extends StatelessWidget {
  const ProductLineCard({
    super.key,
    required this.name,
    this.imageUrl,
    this.brand,
    this.quantity,
    this.unit,
    this.unitPrice,
    this.lineTotal,
    this.additionalDetails = const [],
    this.badge,
    this.footer,
    this.onRelatedExpenses,
    this.onOpenItem,
    this.thumbnailSize = 56,
    this.decorated = true,
  });

  final String name;
  final String? imageUrl;
  final String? brand;
  final num? quantity;
  final String? unit;
  final num? unitPrice;
  final num? lineTotal;
  final List<String> additionalDetails;
  final Widget? badge;
  final Widget? footer;
  final VoidCallback? onRelatedExpenses;
  final VoidCallback? onOpenItem;
  final double thumbnailSize;
  final bool decorated;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (quantity != null)
        '${_compactNumber(quantity!)} ${unit?.trim().isNotEmpty == true ? unit : 'item'}',
      if (unitPrice != null) '${formatMoney(unitPrice)} each',
      ...additionalDetails.where((value) => value.trim().isNotEmpty),
    ];
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductThumbnail(imageUrl: imageUrl, size: thumbnailSize),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate900,
                        ),
                      ),
                    ),
                    if (badge != null) ...[const SizedBox(width: 8), badge!],
                  ],
                ),
                if (brand?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    brand!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    details.join(' · '),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
                if (footer != null) ...[const SizedBox(height: 9), footer!],
              ],
            ),
          ),
          if (lineTotal != null) ...[
            const SizedBox(width: 12),
            Text(
              formatMoney(lineTotal),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.teal600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (onRelatedExpenses != null) ...[
            const SizedBox(width: 4),
            IconButton(
              key: const Key('product-related-expenses-action'),
              tooltip: 'Other expenses with this product',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.receipt_long_outlined,
                size: 19,
                color: AppColors.slate400,
              ),
              onPressed: onRelatedExpenses,
            ),
          ],
          if (onOpenItem != null)
            IconButton(
              key: const Key('product-open-item-action'),
              tooltip: 'Open product page',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.open_in_new,
                size: 18,
                color: AppColors.slate400,
              ),
              onPressed: onOpenItem,
            ),
        ],
      ),
    );

    if (!decorated) return content;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        border: Border.all(color: AppColors.slate100),
        boxShadow: refCardShadow,
      ),
      child: content,
    );
  }
}

class ProductThumbnail extends ConsumerWidget {
  const ProductThumbnail({
    super.key,
    required this.imageUrl,
    required this.size,
  });

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(imageBaseUrlProvider);
    final userId = ref.watch(userIdProvider);
    final path = imageUrl;
    if (base == null || userId == null || path == null || path.isEmpty) {
      return _ProductThumbnailFallback(size: size);
    }
    final normalizedBase = normalizeSuggestionHttpBase(base);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        resolveSuggestionAssetUrl(base, path),
        headers: suggestionHttpHeaders(normalizedBase, userId),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _ProductThumbnailFallback(size: size),
      ),
    );
  }
}

class _ProductThumbnailFallback extends StatelessWidget {
  const _ProductThumbnailFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        size: size * 0.4,
        color: AppColors.slate400,
      ),
    );
  }
}

String _compactNumber(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toString();
}
