import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../utils/cart_provider.dart';

class CartPersistenceNotice extends StatefulWidget {
  const CartPersistenceNotice({
    required this.child,
    required this.navigatorKey,
    super.key,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<CartPersistenceNotice> createState() => _CartPersistenceNoticeState();
}

class _CartPersistenceNoticeState extends State<CartPersistenceNotice> {
  bool _discarding = false;
  bool _discardFailed = false;

  Future<void> _discardUnreadable(CartProvider cart) async {
    final navigatorContext = widget.navigatorKey.currentContext;
    if (_discarding || navigatorContext == null) return;
    setState(() {
      _discarding = true;
      _discardFailed = false;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: navigatorContext,
        builder: (context) {
          final actionStyle = TextButton.styleFrom(
              foregroundColor: context.palette.textPrimary);
          return AlertDialog(
            scrollable: true,
            title: const Text('Очистить сохранённую корзину?'),
            content: const Text(
                'Непрочитанные товары будут удалены. Остальные данные приложения останутся без изменений.'),
            actions: [
              TextButton(
                style: actionStyle,
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              TextButton(
                key: const ValueKey('cart-confirm-discard'),
                style: actionStyle,
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Очистить корзину'),
              ),
            ],
          );
        },
      );
      if (!mounted ||
          confirmed != true ||
          cart.saveStatus.value != CartSaveStatus.restoreFailed) {
        return;
      }
      final saved = await cart.discardForBusiness(cart.businessId);
      if (mounted && !saved) setState(() => _discardFailed = true);
    } finally {
      if (mounted) setState(() => _discarding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    return LayoutBuilder(builder: (context, constraints) {
      final availableHeight =
          (constraints.maxHeight - MediaQuery.viewInsetsOf(context).bottom)
              .clamp(0.0, constraints.maxHeight);
      return ValueListenableBuilder<CartSaveStatus>(
        valueListenable: cart.saveStatus,
        child: widget.child,
        builder: (context, status, content) {
          final palette = context.palette;
          final restoreFailed = status == CartSaveStatus.restoreFailed;
          final showNotice = status == CartSaveStatus.failed || restoreFailed;
          final actionStyle = showNotice
              ? TextButton.styleFrom(foregroundColor: palette.textPrimary)
              : null;
          return Column(
            children: [
              if (showNotice)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: availableHeight / 2),
                  child: SingleChildScrollView(
                    child: Material(
                      color: palette.surface,
                      child: SafeArea(
                        bottom: false,
                        minimum: const EdgeInsets.all(AppSpacing.lg),
                        child: Semantics(
                          liveRegion: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                restoreFailed
                                    ? 'Не удалось восстановить корзину'
                                    : 'Не удалось сохранить корзину',
                                style: AppTypography.title
                                    .copyWith(color: palette.textPrimary),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                restoreFailed
                                    ? 'Сохранённые данные не изменены. Повторите загрузку, чтобы восстановить корзину.'
                                    : 'Изменения остаются в приложении, но могут потеряться после закрытия.',
                                style: AppTypography.bodyMedium
                                    .copyWith(color: palette.textPrimary),
                              ),
                              TextButton(
                                style: actionStyle,
                                onPressed: _discarding
                                    ? null
                                    : () async {
                                        if (restoreFailed) {
                                          await cart.retryLoad();
                                        } else {
                                          await cart.retrySave();
                                        }
                                      },
                                child: Text(restoreFailed
                                    ? 'Повторить загрузку'
                                    : 'Повторить сохранение'),
                              ),
                              if (restoreFailed)
                                TextButton(
                                  key:
                                      const ValueKey('cart-discard-unreadable'),
                                  style: actionStyle,
                                  onPressed: _discarding
                                      ? null
                                      : () => _discardUnreadable(cart),
                                  child: const Text('Очистить корзину'),
                                ),
                              if (restoreFailed && _discardFailed)
                                Text(
                                  'Не удалось очистить корзину. Данные не изменены.',
                                  style: AppTypography.bodyMedium
                                      .copyWith(color: palette.textPrimary),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  child: content!,
                ),
              ),
            ],
          );
        },
      );
    });
  }
}
