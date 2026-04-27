import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_card_webview_page.dart';
import '../shared/app_theme.dart';
import '../utils/api.dart';
import '../utils/responsive.dart';

class ProfileCardsPage extends StatefulWidget {
  const ProfileCardsPage({super.key});

  @override
  State<ProfileCardsPage> createState() => _ProfileCardsPageState();
}

class _ProfileCardsPageState extends State<ProfileCardsPage> with WidgetsBindingObserver {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _cards = <Map<String, dynamic>>[];
  int _revealedCount = 0;
  bool _awaitingCardAdd = false;
  int _cardCountBeforeAdd = 0;
  _ProfileCardFeedback? _cardFeedback;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingCardAdd) {
      _awaitingCardAdd = false;
      _load(showRefreshFeedback: true, previousCount: _cardCountBeforeAdd);
    }
  }

  Future<void> _load({bool showRefreshFeedback = false, int? previousCount}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getFullInfo();
      final cards = (data?['cards'] as List<dynamic>? ?? <dynamic>[]).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _isLoading = false;
      });
      if (showRefreshFeedback) {
        final previous = previousCount ?? 0;
        if (_cards.length > previous) {
          _setCardFeedback('Новая карта сохранена и готова к оплате.', _ProfileCardFeedbackTone.success);
        } else {
          _setCardFeedback(
            'Мы обновили список карт. Если новая карта еще не появилась, завершите привязку в форме банка и попробуйте обновить список снова.',
            _ProfileCardFeedbackTone.info,
          );
        }
      }
      _revealItems();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить карты: $e';
        _isLoading = false;
      });
    }
  }

  void _revealItems() {
    final total = _cards.length;
    _revealedCount = 0;
    for (int i = 0; i < total; i++) {
      Future.delayed(Duration(milliseconds: 60 * i), () {
        if (mounted) setState(() => _revealedCount = i + 1);
      });
    }
    Future.delayed(Duration(milliseconds: 60 * total + 100), () {
      if (mounted && _revealedCount < 999) setState(() => _revealedCount = 999);
    });
  }

  Future<void> _addCard() async {
    _cardCountBeforeAdd = _cards.length;
    final result = await ApiService.generateAddCardLinkResult();
    if (!result.success || result.link == null) {
      _setCardFeedback(result.message, _ProfileCardFeedbackTone.error);
      return;
    }

    final link = result.link!;
    final uri = Uri.tryParse(link);
    if (uri == null) {
      _setCardFeedback('Получена некорректная ссылка для добавления карты. Попробуйте еще раз.', _ProfileCardFeedbackTone.error);
      return;
    }

    if (_supportsEmbeddedCardFlow) {
      if (!mounted) return;
      _setCardFeedback('Открываем защищенную форму банка для привязки карты.', _ProfileCardFeedbackTone.info);
      final shouldRefresh = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => AddCardWebViewPage(initialUrl: link)),
      );
      if (shouldRefresh == true && mounted) {
        await _load(showRefreshFeedback: true, previousCount: _cardCountBeforeAdd);
      }
      return;
    }

    if (await canLaunchUrl(uri)) {
      _awaitingCardAdd = true;
      _setCardFeedback('Открываем форму банка. После возвращения список карт обновится автоматически.', _ProfileCardFeedbackTone.info);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    _setCardFeedback('Не удалось открыть форму банка для привязки карты.', _ProfileCardFeedbackTone.error);
  }

  bool get _supportsEmbeddedCardFlow {
    if (kIsWeb) return false;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  void _setCardFeedback(String message, _ProfileCardFeedbackTone tone) {
    if (!mounted) return;
    setState(() {
      _cardFeedback = _ProfileCardFeedback(message: message, tone: tone);
    });
  }

  Future<void> _refreshOnScroll() async {
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    const scrollPhysics = AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics());

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Мои карты', style: TextStyle(fontWeight: FontWeight.w800)),
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          const AppBackground(),
          RefreshIndicator(
            color: AppColors.orange,
            backgroundColor: AppColors.card,
            onRefresh: _refreshOnScroll,
            child: _isLoading
                ? ListView(
                    physics: scrollPhysics,
                    children: const [
                      SizedBox(
                        height: 520,
                        child: Center(
                          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.orange)),
                        ),
                      ),
                    ],
                  )
                : _error != null
                    ? ListView(
                        physics: scrollPhysics,
                        children: [
                          SizedBox(height: 520, child: _errorView()),
                        ],
                      )
                    : _cards.isEmpty
                        ? ListView(
                            physics: scrollPhysics,
                            children: [
                              SizedBox(height: 560, child: _emptyView()),
                            ],
                          )
                        : ListView.builder(
                            physics: scrollPhysics,
                            padding: EdgeInsets.fromLTRB(14.s, 10.s, 14.s, 24.s),
                            itemCount: _revealedCount.clamp(0, _cards.length) + (_cardFeedback != null ? 2 : 1),
                            itemBuilder: (_, i) {
                              if (i == 0 && _cardFeedback != null) {
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 10.s),
                                  child: _cardFeedbackBanner(_cardFeedback!),
                                );
                              }

                              final offset = _cardFeedback != null ? 1 : 0;
                              if (i == offset + _revealedCount.clamp(0, _cards.length)) {
                                return _addCardButton();
                              }

                              final cardIndex = i - offset;
                              if (cardIndex < 0 || cardIndex >= _cards.length) {
                                return const SizedBox.shrink();
                              }
                              return _animatedCardTile(_cards[cardIndex]);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _animatedCardTile(Map<String, dynamic> card) {
    final id = card['id']?.toString() ?? card['mask']?.toString() ?? card.hashCode.toString();
    return TweenAnimationBuilder<double>(
      key: ValueKey('card_$id'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: _cardTile(card),
    );
  }

  Widget _cardTile(Map<String, dynamic> card) {
    final mask = card['mask']?.toString() ?? '••••';
    final brand = card['brand']?.toString() ?? card['payment_system']?.toString() ?? 'Карта';

    return Container(
      margin: EdgeInsets.only(bottom: 10.s),
      padding: EdgeInsets.all(14.s),
      decoration: AppDecorations.card(radius: 16.s),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.s),
            decoration: AppDecorations.pill(color: AppColors.blue),
            child: const Icon(Icons.credit_card, color: AppColors.orange),
          ),
          SizedBox(width: 10.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mask, style: TextStyle(color: AppColors.text, fontSize: 15.sp, fontWeight: FontWeight.w900)),
                SizedBox(height: 4.s),
                Text(brand, style: const TextStyle(color: AppColors.textMute, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.credit_card_off_outlined, color: AppColors.textMute, size: 48),
            const SizedBox(height: 12),
            const Text('Добавленных карт нет', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'Добавьте карту в защищенной форме банка, и она появится здесь после обновления списка.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMute),
            ),
            if (_cardFeedback != null) ...[
              SizedBox(height: 14.s),
              _cardFeedbackBanner(_cardFeedback!),
            ],
            SizedBox(height: 16.s),
            _addCardButton(expanded: false),
          ],
        ),
      ),
    );
  }

  Widget _addCardButton({bool expanded = true}) {
    final button = OutlinedButton.icon(
      icon: const Icon(Icons.add, color: AppColors.orange),
      label: const Text('Добавить новую карту', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.orange, width: 1.2),
        padding: EdgeInsets.symmetric(vertical: 12.s, horizontal: 12.s),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.s)),
        backgroundColor: Colors.white.withValues(alpha: 0.02),
      ),
      onPressed: _addCard,
    );

    if (expanded) {
      return Padding(
        padding: EdgeInsets.only(top: 6.s),
        child: SizedBox(width: double.infinity, child: button),
      );
    }
    return button;
  }

  Widget _cardFeedbackBanner(_ProfileCardFeedback feedback) {
    final Color accent;
    final IconData icon;
    switch (feedback.tone) {
      case _ProfileCardFeedbackTone.success:
        accent = const Color(0xFF2A8C3E);
        icon = Icons.check_circle_rounded;
      case _ProfileCardFeedbackTone.error:
        accent = AppColors.red;
        icon = Icons.error_outline_rounded;
      case _ProfileCardFeedbackTone.info:
        accent = AppColors.orange;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.s),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16.s),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 18.s),
          SizedBox(width: 10.s),
          Expanded(
            child: Text(
              feedback.message,
              style: TextStyle(color: AppColors.text, fontSize: 12.sp, fontWeight: FontWeight.w700, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.s),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.red),
            SizedBox(height: 12.s),
            Text(_error ?? 'Ошибка', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
            SizedBox(height: 10.s),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.black),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ProfileCardFeedbackTone { success, error, info }

class _ProfileCardFeedback {
  final String message;
  final _ProfileCardFeedbackTone tone;

  const _ProfileCardFeedback({required this.message, required this.tone});
}
