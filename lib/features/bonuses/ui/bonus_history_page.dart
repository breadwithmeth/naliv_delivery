import 'package:flutter/material.dart';

import '../../../ui/app_states.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/app_top_bar.dart';
import '../../../utils/api.dart';
import '../../../utils/cart_provider.dart';
import '../../../ui/app_cart_button.dart';

/// Bonus balance and history — the design's `История бонусов` frames.
///
/// Geometry: the standard top bar, a «Баланс» header at y = 151, a 343 × 56 balance card at
/// y = 193 holding the total (32/900, accent) with a «Как работают бонусы?» link on the right,
/// then «История» at y = 281 and 343 × 63 rows at a 71 px pitch. The empty state is a single
/// centred «История пуста» in muted 20/700 at y = 393.
///
/// **The design's row title has no data source.** Every history entry from `/bonuses` is
/// `{bonusId, organizationId, amount, timestamp}` — there is no order reference and no entry
/// type, so «Заказ №45» from the frame cannot be rendered. The row shows the signed amount and
/// its date instead; recorded in `docs/redesign/STATUS.md`.
class BonusHistoryPage extends StatefulWidget {
  const BonusHistoryPage({this.onHowItWorks, this.onCart, super.key});

  /// Opens the «Как работают бонусы» explainer.
  final VoidCallback? onHowItWorks;
  final VoidCallback? onCart;

  @override
  State<BonusHistoryPage> createState() => _BonusHistoryPageState();
}

class _BonusHistoryPageState extends State<BonusHistoryPage> {
  int? _balance;
  List<Map<String, dynamic>>? _history;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _balance = null;
      _history = null;
    });
    try {
      final response = await ApiService.getUserBonuses();
      final data = response?['data'];
      if (response?['success'] != true || data is! Map) {
        throw StateError('Bonus data is unavailable');
      }
      final rawBalance = data['totalBonuses'];
      final balance =
          rawBalance is num ? rawBalance.toInt() : int.tryParse('$rawBalance');
      final history = data['bonusHistory'];
      if (balance == null || history is! List) {
        throw StateError('Bonus balance or history is unavailable');
      }
      if (!mounted) return;
      setState(() {
        _balance = balance;
        _history = [
          for (final entry in history)
            if (entry is Map) entry.cast<String, dynamic>(),
        ];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cart = context.watch<CartProvider>();
    final count = cart.displayItemCount;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: AppTopBar(
                    title: 'Баланс бонусов по времени',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(height: AppSpacing.huge),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(
                      bottom: AppCartButton.clearanceFor(context) +
                          MediaQuery.paddingOf(context).bottom,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xxxl),
                        child: Row(
                          children: [
                            const AppIcon(AppIcons.bonusStar, size: 24),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Баланс',
                              style: AppTypography.headline
                                  .copyWith(color: palette.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xxxl),
                        child: _BalanceCard(
                          balance: _balance,
                          onHowItWorks: widget.onHowItWorks,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.huge),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xxxl),
                        child: Text(
                          'История',
                          style: AppTypography.headline
                              .copyWith(color: palette.textPrimary),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      ..._rows(palette),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
              child: Center(
                child: AppCartButton(
                  itemCount: count,
                  total: count == 0 ? null : cart.getTotalPrice().round(),
                  onTap: widget.onCart,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _rows(AppPalette palette) {
    if (_failed) {
      return [
        AppErrorState(
          message: 'Не удалось загрузить историю',
          onRetry: _load,
          topOffset: 180,
        ),
      ];
    }
    final history = _history;
    if (history == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.huge),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (history.isEmpty) {
      return const [
        AppEmptyState(title: 'История пуста', muted: true, topOffset: 80)
      ];
    }
    return [
      for (final entry in history)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxxl,
            0,
            AppSpacing.xxxl,
            AppSpacing.md,
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 63),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _amountLabel(entry['amount']),
                  style: AppTypography.titleMedium.copyWith(
                    color: _isCredit(entry['amount'])
                        ? palette.gold
                        : palette.textSecondary,
                  ),
                ),
                Text(
                  _dateLabel(entry['timestamp']),
                  style: AppTypography.base(size: 12, weight: 400)
                      .copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  bool _isCredit(Object? amount) => amount is num && amount > 0;

  String _amountLabel(Object? amount) {
    if (amount is! num) return '—';
    final value = amount.abs().toInt();
    final sign = amount < 0 ? '−' : '+';
    return '$sign$value бонусов';
  }

  String _dateLabel(Object? timestamp) {
    final raw = timestamp?.toString();
    if (raw == null) return '';
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return '';
    return '${DateFormat('d MMMM', 'ru').format(date)} в '
        '${DateFormat('HH:mm').format(date)}';
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, this.onHowItWorks});

  final int? balance;
  final VoidCallback? onHowItWorks;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text.rich(TextSpan(
            children: [
              TextSpan(
                text: '${balance ?? '—'}',
                style:
                    AppTypography.displayLarge.copyWith(color: palette.accent),
              ),
              TextSpan(
                text: ' бонусов',
                style: AppTypography.bodySmallSemibold
                    .copyWith(color: palette.textSecondary),
              ),
            ],
          )),
          TextButton(
            onPressed: onHowItWorks,
            child: const Text('Как работают бонусы?'),
          ),
        ],
      ),
    );
  }
}
