import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/bonus_info_page.dart';
import 'package:naliv_delivery/pages/checkout_page.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import 'package:naliv_delivery/pages/product_detail_page.dart';
import 'package:naliv_delivery/model/item.dart' as item_model;
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/bonus_rules.dart';
import 'package:naliv_delivery/utils/item_name_presentation.dart';
import 'package:naliv_delivery/utils/responsive.dart';
import 'package:provider/provider.dart';
import '../utils/cart_provider.dart';
import '../utils/smart_cart.dart';

class CartPage extends StatelessWidget {
  static const routeName = '/cart';

  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final businessProvider = Provider.of<BusinessProvider>(context);
    final items = cartProvider.displayGroups;
    final total = cartProvider.getTotalPrice();
    final earnedBonuses = _calculateEarnedBonuses(items);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.text,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Column(
          children: [
            Text('Корзина',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp)),
            if (businessProvider.selectedBusinessName != null)
              Text(
                businessProvider.selectedBusiness != null
                    ? '${businessProvider.selectedBusiness!["name"]} — ${businessProvider.selectedBusiness!["address"]}'
                    : 'Выберите магазин',
                style: TextStyle(
                    color: AppColors.textMute,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
      bottomNavigationBar:
          items.isNotEmpty ? _bottomBar(context, total, earnedBonuses) : null,
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: items.isEmpty
                ? _buildEmptyState()
                : _buildList(
                    context, cartProvider, items, total, earnedBonuses),
          ),
        ],
      ),
    );
  }

  // ── Filled state ──────────────────────────────────────────────────

  Widget _buildList(BuildContext context, CartProvider cartProvider,
      List<CartDisplayGroup> items, double total, int earnedBonuses) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.s, 4.s, 16.s, 100.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                  color: Colors.white.withValues(alpha: 0.05), height: 20.s),
            _cartItemRow(context, cartProvider, items[i]),
          ],
          _thinDivider(),
          _summaryRow('Товары', _money(total)),
          if (earnedBonuses > 0) ...[
            SizedBox(height: 6.s),
            _summaryRow('Бонусы за заказ', '+$earnedBonuses ₸',
                valueColor: Colors.greenAccent),
          ],
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 20.s),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Итого',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800)),
              Text(_money(total),
                  style: TextStyle(
                      color: AppColors.orange,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          if (earnedBonuses > 0) ...[
            SizedBox(height: 10.s),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BonusInfoPage())),
              child: Row(
                children: [
                  Icon(Icons.stars_rounded,
                      color: AppColors.orange, size: 14.s),
                  SizedBox(width: 6.s),
                  Text('Как работают бонусы →',
                      style: TextStyle(
                          color: AppColors.orange,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              color: AppColors.textMute, size: 52),
          SizedBox(height: 12),
          Text('Ваша корзина пуста',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── Cart item (flat row) ──────────────────────────────────────────

  Widget _cartItemRow(
      BuildContext context, CartProvider cartProvider, CartDisplayGroup item) {
    final snapshot = item.itemSnapshot;
    final itemTitle = snapshot != null
        ? presentItemName(
            rawName: snapshot.name,
            categoryName: snapshot.category?.name,
          )
        : presentItemName(
            rawName: item.name,
            storedType: item.itemType,
            storedPackagingType: item.packagingType,
          );
    final double? maxAmount = item.maxAmount;
    final bool canIncrease =
        maxAmount == null || item.totalQuantity < maxAmount;
    final bool canDecrease = item.totalQuantity > 0;
    final double freeQty = item.freeQuantity;
    final bool hasFree = freeQty > 0;
    final double rawTotal = item.subtotalBeforePromotions;
    final bool hasSavings = item.totalPrice < rawTotal - 0.001;
    final bottleBreakdown = item.bottleBreakdownLabel;
    final canEditBottles = item.selection?.usesPourFlow == true;
    final quantityLabel = _formatQty(item.totalQuantity);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14.s),
              onTap: snapshot == null
                  ? null
                  : () => Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                            builder: (_) => ProductDetailPage(item: snapshot)),
                      ),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 6.s),
                child: Row(
                  children: [
                    _itemThumb(item.image),
                    SizedBox(width: 10.s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (itemTitle.attributes.isNotEmpty)
                            Text(
                              itemTitle.attributes.join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppColors.textMute,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700),
                            ),
                          Text(
                            itemTitle.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.text,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 4.s),
                          Text(
                            canEditBottles
                                ? quantityLabel
                                : '$quantityLabel ${bottleBreakdown != null ? '• $bottleBreakdown' : ''}'
                                    .trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.textMute,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700),
                          ),
                          if (canEditBottles) ...[
                            SizedBox(height: 6.s),
                            _bottleEditorChip(
                                context, cartProvider, item, bottleBreakdown),
                          ],
                          SizedBox(height: 4.s),
                          if (hasSavings) ...[
                            Row(
                              children: [
                                Text(
                                  _money(rawTotal),
                                  style: TextStyle(
                                    color: AppColors.textMute
                                        .withValues(alpha: 0.5),
                                    fontSize: 11.sp,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: AppColors.textMute
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                SizedBox(width: 6.s),
                                Text(_money(item.totalPrice),
                                    style: TextStyle(
                                        color: AppColors.orange,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                            if (hasFree) ...[
                              SizedBox(height: 2.s),
                              Text(
                                '+ ${_formatQty(freeQty)} в подарок',
                                style: TextStyle(
                                    color: AppColors.orange,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ] else
                            Text(_money(item.totalPrice),
                                style: TextStyle(
                                    color: AppColors.orange,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    if (snapshot != null) ...[
                      SizedBox(width: 8.s),
                      Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMute, size: 18.s),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 8.s),
        _quantityControls(
          value: quantityLabel,
          onDecrement: canDecrease
              ? () => cartProvider.decrementDisplayGroup(item)
              : null,
          onIncrement: canIncrease
              ? () => cartProvider.incrementDisplayGroup(item)
              : null,
        ),
      ],
    );
  }

  Widget _bottleEditorChip(
    BuildContext context,
    CartProvider cartProvider,
    CartDisplayGroup item,
    String? bottleBreakdown,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.s),
        onTap: () => _openBottleEditor(context, cartProvider, item),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 8.s),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12.s),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Icon(Icons.local_drink_outlined,
                  color: AppColors.orange, size: 14.s),
              SizedBox(width: 8.s),
              Expanded(
                child: Text(
                  bottleBreakdown == null || bottleBreakdown.isEmpty
                      ? 'Выбрать тару'
                      : 'Тара: $bottleBreakdown',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(width: 8.s),
              Text(
                'Изменить',
                style: TextStyle(
                    color: AppColors.orange,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openBottleEditor(
      BuildContext context, CartProvider cartProvider, CartDisplayGroup item) {
    final selection = item.selection;
    if (selection == null || !selection.usesPourFlow) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CartBottleSheet(
        bottles: selection.filteredBottles,
        counts: item.bottleCounts,
        volumeForBottle: selection.volumeForBottle,
        volumeLabel: selection.volumeLabel,
        shortName: (bottle) => _shortBottleName(selection, bottle),
        maxAmount: item.maxAmount ?? double.infinity,
        onApply: (counts) =>
            cartProvider.updateDisplayGroupBottleCounts(item, counts),
      ),
    );
  }

  String _shortBottleName(
      SmartCartSelection selection, item_model.ItemOptionItem bottle) {
    final label = bottle.item_name.trim();
    if (label.isNotEmpty) {
      return label;
    }
    return selection.volumeLabel(selection.volumeForBottle(bottle));
  }

  Widget _itemThumb(String? image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.s),
      child: SizedBox(
        width: 44.s,
        height: 44.s,
        child: image != null && image.isNotEmpty
            ? Image.network(image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.inventory_2_outlined,
                    color: AppColors.textMute.withValues(alpha: 0.6),
                    size: 22.s))
            : Icon(Icons.inventory_2_outlined,
                color: AppColors.textMute.withValues(alpha: 0.6), size: 22.s),
      ),
    );
  }

  int _calculateEarnedBonuses(Iterable<CartDisplayGroup> items) {
    final eligibleSubtotal = items.fold<double>(0, (sum, item) {
      final snapshot = item.itemSnapshot;
      final excluded = BonusRules.isBonusExcludedText(
        name: snapshot?.name ?? item.name,
        description: snapshot?.description,
        categoryName: snapshot?.category?.name,
        code: snapshot?.code,
      );
      if (excluded) {
        return sum;
      }
      return sum + item.totalPrice;
    });
    return BonusRules.calculateEarnedBonuses(eligibleSubtotal);
  }

  // ── Quantity controls (lighter capsule) ───────────────────────────

  Widget _quantityControls({
    required String value,
    required VoidCallback? onDecrement,
    required VoidCallback? onIncrement,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _qtyBtn(Icons.remove, onDecrement, false),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.s),
          child: Text(value,
              style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.sp)),
        ),
        _qtyBtn(Icons.add, onIncrement, true),
      ],
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onPressed, bool filled) {
    final Color bg = filled ? AppColors.orange : AppColors.card;
    final Color fg = filled ? Colors.black : AppColors.text;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 28.s,
        height: 28.s,
        decoration: BoxDecoration(
          color: onPressed == null ? bg.withValues(alpha: 0.4) : bg,
          borderRadius: BorderRadius.circular(10.s),
        ),
        child: Icon(icon,
            size: 15.s,
            color: fg.withValues(alpha: onPressed == null ? 0.4 : 1)),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────

  Widget _thinDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.s),
      child: Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
    );
  }

  Widget _summaryRow(String label, String value,
      {Color valueColor = AppColors.text}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(color: AppColors.textMute, fontSize: 12.sp)),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────

  Widget _bottomBar(BuildContext context, double total, int earnedBonuses) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.s, 10.s, 16.s, 10.s),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_money(total),
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w900)),
                if (earnedBonuses > 0)
                  Text('+$earnedBonuses ₸ бонусов',
                      style: TextStyle(
                          color: AppColors.textMute,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600)),
              ],
            ),
            SizedBox(width: 14.s),
            Expanded(
              child: _primaryButton(
                context: context,
                label: 'Оформить',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton(
      {required BuildContext context, required String label}) {
    return GestureDetector(
      onTap: () async {
        final loggedIn = await ApiService.isUserLoggedIn();
        if (!context.mounted) return;
        if (loggedIn) {
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => const CheckoutPage()));
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const LoginPage(
                redirectTabIndex: 3,
                openCheckoutOnSuccess: true,
              ),
            ),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23.s),
          gradient:
              const LinearGradient(colors: [Color(0xFF8B1F1E), AppColors.red]),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_forward, color: Colors.white, size: 16.s),
            SizedBox(width: 9.s),
            Text(label,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  // ── Utils ─────────────────────────────────────────────────────────

  static String _formatQty(double qty) {
    return (qty - qty.roundToDouble()).abs() < 0.001
        ? qty.toStringAsFixed(0)
        : qty.toStringAsFixed(2);
  }

  static String _money(double value) => '${value.toStringAsFixed(0)} ₸';
}

class _CartBottleSheet extends StatefulWidget {
  const _CartBottleSheet({
    required this.bottles,
    required this.counts,
    required this.volumeForBottle,
    required this.volumeLabel,
    required this.shortName,
    required this.maxAmount,
    required this.onApply,
  });

  final List<item_model.ItemOptionItem> bottles;
  final Map<int, int> counts;
  final double Function(item_model.ItemOptionItem) volumeForBottle;
  final String Function(double) volumeLabel;
  final String Function(item_model.ItemOptionItem) shortName;
  final double maxAmount;
  final void Function(Map<int, int>) onApply;

  @override
  State<_CartBottleSheet> createState() => _CartBottleSheetState();
}

class _CartBottleSheetState extends State<_CartBottleSheet> {
  late final Map<int, int> _counts;

  @override
  void initState() {
    super.initState();
    _counts = Map<int, int>.of(widget.counts);
  }

  double _totalLiters() {
    var total = 0.0;
    for (final bottle in widget.bottles) {
      final count = _counts[bottle.relationId] ?? 0;
      if (count > 0) {
        total += widget.volumeForBottle(bottle) * count;
      }
    }
    return total;
  }

  int _totalBottles() =>
      _counts.values.fold<int>(0, (sum, count) => sum + count);

  void _change(item_model.ItemOptionItem bottle, int delta) {
    final currentLiters = _totalLiters();
    final bottleVolume = widget.volumeForBottle(bottle);
    final currentCount = _counts[bottle.relationId] ?? 0;
    final nextCount = (currentCount + delta).clamp(0, 999);
    final nextLiters =
        currentLiters + ((nextCount - currentCount) * bottleVolume);
    if (nextLiters > widget.maxAmount + 0.001) {
      return;
    }

    setState(() {
      _counts[bottle.relationId] = nextCount;
    });
  }

  void _apply() {
    widget.onApply(_counts);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final liters = _totalLiters();
    final bottleCount = _totalBottles();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(18.s, 10.s, 18.s, 14.s + pad.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32.s,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 18.s),
          Row(
            children: [
              Text(
                'Изменить тару',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${widget.volumeLabel(liters)} · $bottleCount бут.',
                style: TextStyle(
                    color: AppColors.textMute,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 18.s),
          ...widget.bottles.map((bottle) {
            final count = _counts[bottle.relationId] ?? 0;
            final volume = widget.volumeForBottle(bottle);
            final canAdd = liters + volume <= widget.maxAmount + 0.001;
            return Padding(
              padding: EdgeInsets.only(bottom: 9.s),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 10.s),
                decoration: BoxDecoration(
                  color: count > 0 ? AppColors.blue : AppColors.cardDark,
                  borderRadius: BorderRadius.circular(12.s),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.shortName(bottle),
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    _sheetStepBtn(
                      Icons.remove_rounded,
                      count > 0 ? () => _change(bottle, -1) : null,
                    ),
                    SizedBox(
                      width: 36.s,
                      child: Center(
                        child: Text(
                          '$count',
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    _sheetStepBtn(
                      Icons.add_rounded,
                      canAdd ? () => _change(bottle, 1) : null,
                    ),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: 10.s),
          SizedBox(
            width: double.infinity,
            height: 48.s,
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.s)),
              ),
              child: Text(
                'Готово',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetStepBtn(IconData icon, VoidCallback? onTap) {
    return Material(
      color: onTap != null
          ? AppColors.blue
          : AppColors.blue.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(11.s),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11.s),
        child: SizedBox(
          width: 36.s,
          height: 36.s,
          child: Icon(
            icon,
            size: 18.s,
            color: onTap != null
                ? AppColors.text
                : AppColors.textMute.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
