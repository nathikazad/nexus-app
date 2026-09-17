import 'package:url_launcher/url_launcher.dart';
import 'package:nx_expense/features/desktop/desktop_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nx_expense/core/formatting/format.dart';
import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/domain/order/order.dart';
import 'package:nx_expense/features/products/widgets/product_line_card.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderDetailProvider(orderId));

    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => navBack(context, fallback: '/orders'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => navBack(context, fallback: '/orders'),
          ),
        ),
        body: Center(
          child: TextButton(
            onPressed: () => ref.invalidate(orderDetailProvider(orderId)),
            child: const Text('Unable to load order. Retry'),
          ),
        ),
      ),
      data: (order) {
        if (order == null) {
          return Scaffold(
            appBar: AppBar(
              leading: BackButton(
                onPressed: () => navBack(context, fallback: '/orders'),
              ),
            ),
            body: const Center(child: Text('Order not found')),
          );
        }
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.slate400,
                size: 22,
              ),
              onPressed: () => navBack(context),
            ),
            centerTitle: true,
            title: Text(
              order.orderNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: refAppBarTitleBase(),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: AppColors.slate100),
            ),
          ),
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              _OrderHeader(order: order),
              if (order.sourceUrl != null)
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('Open original order'),
                  subtitle: Text(Uri.parse(order.sourceUrl!).host),
                  onTap: () => _openOrderUrl(context, order.sourceUrl!),
                ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Related expenses'),
                onTap: () => navToRelationExpenses(
                  context,
                  ref,
                  relName: 'Order',
                  relId: order.id,
                  displayName: order.orderNumber,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  RefLayout.px5,
                  24,
                  RefLayout.px5,
                  8,
                ),
                child: Text('Products', style: refSectionTitle(context)),
              ),
              if (order.products.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    RefLayout.px5,
                    8,
                    RefLayout.px5,
                    0,
                  ),
                  child: Text(
                    'No products found',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.slate500,
                    ),
                  ),
                )
              else
                for (final product in order.products)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      RefLayout.px5,
                      0,
                      RefLayout.px5,
                      8,
                    ),
                    child: ProductLineCard(
                      name: product.name,
                      quantity: product.quantity,
                      unit: product.unit,
                      unitPrice: product.unitPrice,
                      lineTotal: product.effectiveLineTotal,
                      imageUrl: product.imageUrl,
                      onOpenItem: _webUri(product.itemUrl) == null
                          ? null
                          : () => _openOrderUrl(context, product.itemUrl!),
                      onRelatedExpenses: () => navToRelationExpenses(
                        context,
                        ref,
                        relName: 'Product',
                        relId: product.id,
                        displayName: product.name,
                      ),
                      additionalDetails: [
                        if (product.tax != null)
                          'Tax ${formatMoney(product.tax)}',
                        if (product.status != null) product.status!,
                        if (product.deliveryDate != null) product.deliveryDate!,
                      ],
                    ),
                  ),
              const SizedBox(height: RefLayout.pb24),
            ],
          ),
        );
      },
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final refundTotal = _moneyFromExtras(order.extras?['refund_total']);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 36,
        horizontal: RefLayout.px5,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.slate100)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0FDFA), Color(0xFFF8FAFC), Colors.white],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.teal100),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: AppColors.teal700,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ORDER TOTAL',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: AppColors.slate500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            formatMoney(order.total),
            style: GoogleFonts.inter(
              fontSize: 40,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              height: 1,
              color: AppColors.teal600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 8,
            children: [
              _HeaderFact(
                icon: Icons.storefront_outlined,
                text: order.companyName ?? 'Unknown',
              ),
              _HeaderFact(
                icon: Icons.calendar_today_outlined,
                text: formatModelDate(order.orderDate),
              ),
              _HeaderFact(
                icon: Icons.inventory_2_outlined,
                text: order.itemCount == 1
                    ? '1 item'
                    : '${order.itemCount} items',
              ),
              if (refundTotal != null)
                _HeaderFact(
                  icon: Icons.undo_outlined,
                  text: 'Refund ${formatMoney(refundTotal)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderFact extends StatelessWidget {
  const _HeaderFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.slate400),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.slate500,
          ),
        ),
      ],
    );
  }
}

num? _moneyFromExtras(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw;
  final cleaned = raw.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (cleaned.isEmpty) return null;
  return num.tryParse(cleaned);
}

Uri? _webUri(String? value) {
  final uri = value == null ? null : Uri.tryParse(value);
  return uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty
      ? uri
      : null;
}

Future<void> _openOrderUrl(BuildContext context, String value) async {
  final uri = _webUri(value);
  if (uri == null) return;
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    /* Surface failures without leaving the order. */
  }
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unable to open this link')));
  }
}
