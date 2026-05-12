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
import 'package:naliv_delivery/utils/subtract_promotion_math.dart';
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
            Text('Корзина', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp)),
            if (businessProvider.selectedBusinessName != null)
              Text(
                businessProvider.selectedBusiness != null
                    ? '${businessProvider.selectedBusiness!["name"]} — ${businessProvider.selectedBusiness!["address"]}'
                    : 'Выберите магазин',
                style: TextStyle(color: AppColors.textMute, fontSize: 11.sp, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
      bottomNavigationBar: items.isNotEmpty ? _bottomBar(context, total, earnedBonuses) : null,
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: items.isEmpty ? _buildEmptyState() : _buildList(context, cartProvider, items, total, earnedBonuses),
          ),
        ],
      ),
    );
  }

  // ── Filled state ──────────────────────────────────────────────────

  Widget _buildList(BuildContext context, CartProvider cartProvider, List<CartDisplayGroup> items, double total, int earnedBonuses) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.s, 8.s, 16.s, 112.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(color: Colors.white.withValues(alpha: 0.05), height: 20.s),
            _cartItemRow(context, cartProvider, items[i]),
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
          Icon(Icons.shopping_cart_outlined, color: AppColors.textMute, size: 52),
          SizedBox(height: 12),
          Text('Ваша корзина пуста', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── Cart item (flat row) ──────────────────────────────────────────

  Widget _cartItemRow(BuildContext context, CartProvider cartProvider, CartDisplayGroup item) {
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
    final bool hasSnapshot = snapshot != null;
    final double nextIncreaseQuantity = hasSnapshot ? _nextDisplayGroupQuantity(item, direction: 1) : item.totalQuantity;
    final bool canIncrease = hasSnapshot
        ? nextIncreaseQuantity > item.totalQuantity + subtractPromotionEpsilon &&
            (maxAmount == null || nextIncreaseQuantity <= maxAmount + subtractPromotionEpsilon)
        : maxAmount == null || item.totalQuantity < maxAmount;
    final bool canDecrease = item.totalQuantity > 0;
    final double rawTotal = item.subtotalBeforePromotions;
    final bool hasSavings = item.totalPrice < rawTotal - 0.001;
    final bottleBreakdown = item.bottleBreakdownLabel;
    final canEditBottles = item.selection?.usesPourFlow == true;
    final quantityLabel = _quantityLabel(item, item.totalQuantity);
    final amountLabel = _amountLabel(item, item.totalQuantity);
    final inlineMeta = bottleBreakdown ?? _subtitleMeta(itemTitle);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                          builder: (_) => ProductDetailPage(
                            item: snapshot,
                            initialBaseVariants: item.baseVariants,
                          ),
                        ),
                      ),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.s),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _itemThumb(item.image),
                    SizedBox(width: 12.s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: itemTitle.name,
                                  style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w800,
                                    height: 1.22,
                                  ),
                                ),
                                TextSpan(
                                  text: ' · $amountLabel',
                                  style: TextStyle(
                                    color: AppColors.textMute,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    height: 1.22,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (inlineMeta != null && inlineMeta.isNotEmpty) ...[
                            SizedBox(height: 4.s),
                            _inlineMetaRow(
                              context,
                              cartProvider,
                              item,
                              inlineMeta,
                              canEditBottles,
                            ),
                          ],
                          SizedBox(height: 10.s),
                          Wrap(
                            spacing: 8.s,
                            runSpacing: 2.s,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _money(item.totalPrice),
                                style: TextStyle(
                                  color: AppColors.orange,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (hasSavings)
                                Text(
                                  _money(rawTotal),
                                  style: TextStyle(
                                    color: AppColors.textMute.withValues(alpha: 0.52),
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: AppColors.textMute.withValues(alpha: 0.52),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 10.s),
        Padding(
          padding: EdgeInsets.only(top: 8.s),
          child: _quantityControls(
            value: quantityLabel,
            onDecrement: canDecrease ? () => _decrementDisplayGroup(cartProvider, item) : null,
            onIncrement: canIncrease ? () => _incrementDisplayGroup(cartProvider, item) : null,
          ),
        ),
      ],
    );
  }

  Widget _inlineMetaRow(
    BuildContext context,
    CartProvider cartProvider,
    CartDisplayGroup item,
    String meta,
    bool canEditBottles,
  ) {
    final metaText = Text(
      meta,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.textMute,
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
      ),
    );

    if (!canEditBottles) {
      return metaText;
    }

    return Row(
      children: [
        Expanded(child: metaText),
        SizedBox(width: 8.s),
        GestureDetector(
          onTap: () => _openBottleEditor(context, cartProvider, item),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, color: AppColors.orange, size: 12.s),
              SizedBox(width: 4.s),
              Text(
                'Изменить',
                style: TextStyle(
                  color: AppColors.orange,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openBottleEditor(BuildContext context, CartProvider cartProvider, CartDisplayGroup item) {
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
        onApply: (counts) => cartProvider.updateDisplayGroupBottleCounts(item, counts),
      ),
    );
  }

  String _shortBottleName(SmartCartSelection selection, item_model.ItemOptionItem bottle) {
    final label = bottle.itemName.trim();
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
                errorBuilder: (_, __, ___) => Icon(Icons.inventory_2_outlined, color: AppColors.textMute.withValues(alpha: 0.6), size: 22.s))
            : Icon(Icons.inventory_2_outlined, color: AppColors.textMute.withValues(alpha: 0.6), size: 22.s),
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
          child: Text(value, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 13.sp)),
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
        child: Icon(icon, size: 15.s, color: fg.withValues(alpha: onPressed == null ? 0.4 : 1)),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────

  // ── Bottom bar ────────────────────────────────────────────────────

  Widget _bottomBar(BuildContext context, double total, int earnedBonuses) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.s, 12.s, 16.s, 10.s),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Итого', style: TextStyle(color: AppColors.textMute, fontSize: 11.sp, fontWeight: FontWeight.w700)),
                SizedBox(height: 2.s),
                Text(_money(total), style: TextStyle(color: AppColors.text, fontSize: 20.sp, fontWeight: FontWeight.w900)),
                if (earnedBonuses > 0)
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BonusInfoPage())),
                    child: Padding(
                      padding: EdgeInsets.only(top: 4.s),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: AppColors.orange, size: 12.s),
                          SizedBox(width: 5.s),
                          Text(
                            '+$earnedBonuses бонусов',
                            style: TextStyle(color: AppColors.orange, fontSize: 11.sp, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(width: 4.s),
                          Icon(Icons.info_outline_rounded, color: AppColors.textMute, size: 12.s),
                        ],
                      ),
                    ),
                  ),
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

  Widget _primaryButton({required BuildContext context, required String label}) {
    return GestureDetector(
      onTap: () async {
        final loggedIn = await ApiService.isUserLoggedIn();
        if (!context.mounted) return;
        if (loggedIn) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutPage()));
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
          gradient: const LinearGradient(
            colors: [Color(0xFFFFC255), AppColors.orange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_forward, color: Colors.black, size: 16.s),
            SizedBox(width: 9.s),
            Text(label, style: TextStyle(color: Colors.black, fontSize: 14.sp, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  String? _subtitleMeta(ItemTitlePresentation title) {
    if (title.attributes.isEmpty) {
      return null;
    }
    return title.attributes.join(' • ');
  }

  void _incrementDisplayGroup(CartProvider cartProvider, CartDisplayGroup item) {
    final snapshot = item.itemSnapshot;
    if (snapshot == null) {
      cartProvider.incrementDisplayGroup(item);
      return;
    }

    final nextQuantity = _nextDisplayGroupQuantity(item, direction: 1);
    if (nextQuantity <= item.totalQuantity + subtractPromotionEpsilon) {
      return;
    }
    if (item.maxAmount != null && nextQuantity > item.maxAmount! + subtractPromotionEpsilon) {
      return;
    }

    cartProvider.syncItemSelectionQuantity(snapshot, item.baseVariants, nextQuantity);
  }

  void _decrementDisplayGroup(CartProvider cartProvider, CartDisplayGroup item) {
    final snapshot = item.itemSnapshot;
    if (snapshot == null) {
      cartProvider.decrementDisplayGroup(item);
      return;
    }

    final nextQuantity = _nextDisplayGroupQuantity(item, direction: -1);
    cartProvider.syncItemSelectionQuantity(snapshot, item.baseVariants, nextQuantity);
  }

  double _nextDisplayGroupQuantity(CartDisplayGroup item, {required int direction}) {
    final selection = item.selection;
    if (selection == null) {
      return item.totalQuantity;
    }

    final promoTarget = subtractPromotionBundleTargetQuantity(
      item.totalQuantity,
      item.promotions,
      direction: direction,
    );
    if (promoTarget != null) {
      return promoTarget;
    }

    return selection.clampQuantity(item.totalQuantity + (selection.defaultStepQuantity * direction));
  }

  String _quantityLabel(CartDisplayGroup item, double quantity) {
    return subtractPromotionBundleLabel(
      quantity,
      item.promotions,
      formatQuantity: _formatQty,
    );
  }

  String _amountLabel(CartDisplayGroup item, double quantity) {
    final snapshot = item.itemSnapshot;
    final unit = snapshot?.unit?.trim();
    final formatted = _quantityLabel(item, quantity);
    if (item.selection?.usesPourFlow == true) {
      return '$formatted л';
    }
    if (unit != null && unit.isNotEmpty) {
      return '$formatted $unit';
    }
    return '$formatted шт.';
  }

  // ── Utils ─────────────────────────────────────────────────────────

  static String _formatQty(double qty) {
    return (qty - qty.roundToDouble()).abs() < 0.001 ? qty.toStringAsFixed(0) : qty.toStringAsFixed(2);
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

  int _totalBottles() => _counts.values.fold<int>(0, (sum, count) => sum + count);

  void _change(item_model.ItemOptionItem bottle, int delta) {
    final currentLiters = _totalLiters();
    final bottleVolume = widget.volumeForBottle(bottle);
    final currentCount = _counts[bottle.relationId] ?? 0;
    final nextCount = (currentCount + delta).clamp(0, 999);
    final nextLiters = currentLiters + ((nextCount - currentCount) * bottleVolume);
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
                style: TextStyle(color: AppColors.text, fontSize: 16.sp, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${widget.volumeLabel(liters)} · $bottleCount бут.',
                style: TextStyle(color: AppColors.textMute, fontSize: 12.sp, fontWeight: FontWeight.w600),
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
                        style: TextStyle(color: AppColors.text, fontSize: 14.sp, fontWeight: FontWeight.w700),
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
                          style: TextStyle(color: AppColors.text, fontSize: 15.sp, fontWeight: FontWeight.w900),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.s)),
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
      color: onTap != null ? AppColors.blue : AppColors.blue.withValues(alpha: 0.4),
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
            color: onTap != null ? AppColors.text : AppColors.textMute.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
