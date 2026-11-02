import 'dart:async';

import 'package:flutter/material.dart';

import '../../../ui/app_states.dart';
import 'package:provider/provider.dart';

import '../../../design/theme.dart';
import '../../../design/typography.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/app_top_bar.dart';
import '../../../ui/liquid_glass_dock.dart';
import '../../../utils/api.dart';
import '../../../services/auth_service.dart';
import '../../../utils/cart_provider.dart';
import '../../../ui/app_cart_button.dart';
import '../../../pages/order_detail_page.dart';
import '../../../ui/surfaces.dart';
import '../bonus_account.dart';
import 'bonus_how_it_works_page.dart';
import 'bonus_ledger_row.dart';

/// Displays the latest server balance and signed ledger operations.
class BonusHistoryPage extends StatefulWidget {
  const BonusHistoryPage({this.onHowItWorks, this.onCart, super.key});

  /// Opens the «Как работают бонусы» explainer.
  final FutureOr<void> Function()? onHowItWorks;
  final VoidCallback? onCart;

  @override
  State<BonusHistoryPage> createState() => _BonusHistoryPageState();
}

class _BonusHistoryPageState extends State<BonusHistoryPage>
    with WidgetsBindingObserver {
  BonusAccount? _account;
  bool _loading = false;
  bool _failed = false;
  int _credentialRevision = AuthService.credentialRevision;
  int _requestRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService.sessionRevision.addListener(_sessionChanged);
    _load();
  }

  @override
  void dispose() {
    AuthService.sessionRevision.removeListener(_sessionChanged);
    _requestRevision++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  void _sessionChanged() {
    final revision = AuthService.credentialRevision;
    if (!mounted || revision == _credentialRevision) return;
    _credentialRevision = revision;
    _requestRevision++;
    setState(() {
      _account = null;
      _loading = false;
      _failed = false;
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading) return;
    final request = ++_requestRevision;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final session = await AuthService.captureSession();
      if (!mounted || request != _requestRevision) return;
      if (session == null) {
        setState(() => _failed = true);
        return;
      }
      final response = await ApiService.getUserBonuses(
        credentialToken: session.token,
      );
      if (!mounted || request != _requestRevision || !session.isCurrent) return;
      final account = BonusAccount.fromResponse(response);
      setState(() => _account = account);
    } catch (_) {
      if (mounted && request == _requestRevision) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && request == _requestRevision) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openHowItWorks() async {
    final open = widget.onHowItWorks;
    if (open != null) {
      await open();
    } else {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const BonusHowItWorksPage(),
      ));
    }
    if (mounted) await _load();
  }

  Future<void> _openOrder(BonusLedgerEntry entry) async {
    final id = int.tryParse(entry.orderId ?? '');
    if (id == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => OrderDetailPage(order: {'order_id': id}),
    ));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cart = context.watch<CartProvider>();
    final count = cart.displayItemCount;
    final account = _account;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: LiquidGlassDock(
              content: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppTopBar(
                      title: 'Баланс бонусов по времени',
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      AppIcon(AppIcons.bonusStar,
                                          size: 22, color: palette.accent),
                                      const SizedBox(width: 6),
                                      Text('Баланс',
                                          style: AppTypography.headline
                                              .copyWith(
                                                  color: palette.textPrimary)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _BalanceCard(
                                    balance: account?.balance,
                                    onHowItWorks: _openHowItWorks,
                                  ),
                                  if (_loading)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: LinearProgressIndicator(),
                                    ),
                                  if (_failed)
                                    AppErrorState(
                                      message: account == null
                                          ? 'Не удалось загрузить баланс и историю'
                                          : 'Не удалось обновить бонусы. Показаны ранее полученные данные.',
                                      onRetry: _load,
                                      topOffset: 16,
                                    ),
                                  if (account?.history.isNotEmpty == true) ...[
                                    const SizedBox(height: 28),
                                    Text('История',
                                        style: AppTypography.headline.copyWith(
                                            color: palette.textPrimary)),
                                    const SizedBox(height: 16),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (account != null && account.history.isEmpty)
                            const SliverToBoxAdapter(
                              child: AppEmptyState(
                                title: 'История пуста',
                                muted: true,
                                topOffset: 136,
                              ),
                            ),
                          if (account != null)
                            SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final entry = account.history[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: BonusLedgerRow(
                                        entry: entry,
                                        onTap:
                                            int.tryParse(entry.orderId ?? '') ==
                                                    null
                                                ? null
                                                : () => _openOrder(entry),
                                      ),
                                    );
                                  },
                                  childCount: account.history.length,
                                ),
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: AppCartButton.clearanceFor(context) +
                                  MediaQuery.paddingOf(context).bottom,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              dock: widget.onCart == null
                  ? null
                  : AppCartButton(
                      itemCount: count,
                      total: count == 0 ? null : cart.getTotalPrice().round(),
                      onTap: widget.onCart,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.onHowItWorks});

  final num? balance;
  final VoidCallback onHowItWorks;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final amount = Text.rich(
      TextSpan(children: [
        TextSpan(
          text: balance == null ? '—' : bonusNumberLabel(balance!),
          style: AppTypography.displayLarge.copyWith(color: palette.accent),
        ),
        TextSpan(
          text: ' бонусов',
          style: AppTypography.bodySmallSemibold
              .copyWith(color: palette.textSecondary),
        ),
      ]),
      key: const ValueKey('bonus-balance'),
    );
    final help = TextButton.icon(
      key: const ValueKey('bonus-how-it-works'),
      onPressed: onHowItWorks,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(44, 44),
      ),
      icon: const Icon(Icons.open_in_new_rounded, size: 16),
      label: const Text('Как работают\nбонусы?'),
    );
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(16) > 21) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [amount, help],
          );
        }
        return Row(
          children: [
            Expanded(child: amount),
            const SizedBox(width: 8),
            help,
          ],
        );
      }),
    );
  }
}
