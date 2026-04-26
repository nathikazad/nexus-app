import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cooking/core/layout/layout.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/data/providers.dart';
import 'package:nx_cooking/domain/shopping.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

class BuyPage extends ConsumerWidget {
  const BuyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shoppingSnapshotProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load shopping list.\n$e',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.zinc600),
          ),
        ),
      ),
      data: (snap) => _BuyListBody(snap: snap),
    );
  }
}

class _BuyListBody extends StatefulWidget {
  const _BuyListBody({required this.snap});

  final ShoppingListSnapshot snap;

  @override
  State<_BuyListBody> createState() => _BuyListBodyState();
}

class _BuyListBodyState extends State<_BuyListBody> {
  List<List<bool>>? _checked;

  static List<List<bool>> _fromSnapshot(ShoppingListSnapshot snap) {
    return snap.groups
        .map((g) => g.items.map((e) => e.initialChecked).toList())
        .toList();
  }

  static String _signature(ShoppingListSnapshot snap) {
    final b = StringBuffer();
    for (final g in snap.groups) {
      b.write(g.header);
      for (final i in g.items) {
        b.write('|${i.name}|${i.amount}|${i.initialChecked}');
      }
      b.write(';');
    }
    return b.toString();
  }

  @override
  void initState() {
    super.initState();
    _checked = _fromSnapshot(widget.snap);
  }

  @override
  void didUpdateWidget(covariant _BuyListBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_signature(oldWidget.snap) != _signature(widget.snap)) {
      _checked = _fromSnapshot(widget.snap);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snap;
    _checked ??= _fromSnapshot(snap);

    if (snap.groups.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          CookingLayout.screenPadding,
          40,
          CookingLayout.screenPadding,
          CookingLayout.bottomNavExtra + 88,
        ),
        children: const [
          Icon(SolarLinearIcons.cartLarge, size: 40, color: AppColors.zinc300),
          SizedBox(height: 16),
          Text(
            'Nothing to buy this week',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.zinc600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Plan a recipe from the Recipes tab to see ingredients here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.zinc500),
          ),
        ],
      );
    }

    final purchased = _checked!.expand((e) => e).where((c) => c).length;
    final total = snap.totalCount;
    final progress = total == 0 ? 0.0 : purchased / total;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CookingLayout.screenPadding,
        20,
        CookingLayout.screenPadding,
        CookingLayout.bottomNavExtra + 88,
      ),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: AppColors.orange100,
            color: AppColors.orange500,
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$purchased / $total items',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.orange700,
            ),
          ),
        ),
        const SizedBox(height: 20),
        for (var g = 0; g < snap.groups.length; g++) ...[
          if (g > 0) const SizedBox(height: 26),
          _GroupHeader(title: snap.groups[g].header),
          const SizedBox(height: 10),
          _ShoppingGroupBox(
            group: snap.groups[g],
            checked: _checked![g],
            onToggle: (i, v) {
              setState(() {
                _checked![g][i] = v;
              });
            },
          ),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          SolarLinearIcons.calendar,
          size: 16,
          color: AppColors.zinc400,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.4,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppColors.zinc400,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShoppingGroupBox extends StatelessWidget {
  const _ShoppingGroupBox({
    required this.group,
    required this.checked,
    required this.onToggle,
  });

  final ShoppingMealGroup group;
  final List<bool> checked;
  final void Function(int itemIndex, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.zinc200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (var i = 0; i < group.items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.zinc100),
            _ItemRow(
              item: group.items[i],
              checked: checked[i],
              onChanged: (v) => onToggle(i, v),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.checked,
    required this.onChanged,
  });

  final ShoppingItem item;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: checked ? AppColors.zinc50 : Colors.white,
      child: InkWell(
        onTap: () => onChanged(!checked),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: checked,
                  onChanged: (v) => onChanged(v ?? false),
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.orange500;
                    }
                    return Colors.transparent;
                  }),
                  checkColor: Colors.white,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: AppColors.zinc300, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: checked ? AppColors.zinc400 : AppColors.zinc900,
                    decoration: checked ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Text(
                item.amount,
                style: TextStyle(
                  fontSize: 12,
                  color: checked ? AppColors.zinc400 : AppColors.zinc400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
