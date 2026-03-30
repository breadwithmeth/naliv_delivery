import 'package:flutter/material.dart';

import '../shared/app_theme.dart';
import '../utils/api.dart';
import '../utils/responsive.dart';

class ProfileCardsPage extends StatefulWidget {
  const ProfileCardsPage({super.key});

  @override
  State<ProfileCardsPage> createState() => _ProfileCardsPageState();
}

class _ProfileCardsPageState extends State<ProfileCardsPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _cards = <Map<String, dynamic>>[];
  int _revealedCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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

  @override
  Widget build(BuildContext context) {
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
          if (_isLoading)
            const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.orange)))
          else if (_error != null)
            _errorView()
          else if (_cards.isEmpty)
            _emptyView()
          else
            ListView.builder(
              padding: EdgeInsets.fromLTRB(14.s, 10.s, 14.s, 24.s),
              itemCount: _revealedCount.clamp(0, _cards.length),
              itemBuilder: (_, i) => _animatedCardTile(_cards[i]),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.credit_card_off_outlined, color: AppColors.textMute, size: 48),
            SizedBox(height: 12),
            Text('Добавленных карт нет', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text(
              'Оплата картой пока недоступна. Добавьте карту в процессе заказа.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMute),
            ),
          ],
        ),
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
