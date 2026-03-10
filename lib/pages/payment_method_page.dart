import 'package:flutter/material.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentMethodPage extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const PaymentMethodPage({Key? key, required this.orderData}) : super(key: key);

  @override
  _PaymentMethodPageState createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> with WidgetsBindingObserver {
  List<Map<String, dynamic>>? _cards;
  bool _isLoading = true;
  String? _selectedCardId;
  bool _awaitingCardAdd = false;
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCards();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingCardAdd) {
      // Вернулись из внешнего браузера — обновляем карты один раз
      _awaitingCardAdd = false;
      _loadCards();
    }
  }

  Future<void> _loadCards() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final cards = await ApiService.getUserCards(source: 'halyk');
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _isLoading = false;
        if (_cards != null && _cards!.isNotEmpty) {
          _selectedCardId = _cards!.first['halyk_id'].toString();
        } else {
          _selectedCardId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки карт: $e')),
      );
    }
  }

  Future<void> _addCard() async {
    final link = await ApiService.generateAddCardLink();
    if (link != null) {
      final uri = Uri.parse(link);
      if (await canLaunchUrl(uri)) {
        _awaitingCardAdd = true;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть ссылку для добавления карты')),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось получить ссылку для добавления карты')),
      );
    }
  }

  Future<void> _pay() async {
    if (_isPaying || _isLoading) return;
    if (_selectedCardId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пожалуйста, выберите карту для оплаты')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isPaying = true;
      });
    }

    // Показываем индикатор загрузки в фирменном стиле
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AppDialogs.dialog(
          title: 'Оплата',
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange)),
                ),
                SizedBox(width: 12),
                Text('Проводим оплату...'),
              ],
            ),
          ),
        ),
      );
    }

    try {
      final orderId = widget.orderData['order_id']?.toString() ?? widget.orderData['order_uuid']?.toString();
      if (orderId == null) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка: ID заказа не найден')),
          );
        }
        return;
      }

      final result = await ApiService.payOrder(orderId, _selectedCardId!);

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (result['success'] == true) {
        // Успешная оплата
        final paymentData = result['data'];
        final paymentStatus = paymentData['payment_status'];

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Оплата успешно проведена! Статус: $paymentStatus'),
              backgroundColor: Colors.green,
            ),
          );

          // Возвращаемся на главную страницу после успешной оплаты
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        // Ошибка оплаты
        final errorMessage = result['error'] is Map ? result['error']['message'] : result['error'].toString();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка оплаты: $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Произошла ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPaying = false;
        });
      }
    }
  }

  /// Получить сумму заказа из различных возможных полей
  String _getOrderAmount() {
    final orderData = widget.orderData;

    // Проверяем различные возможные поля для суммы
    final amount = orderData['total_sum'] ??
        orderData['total_amount'] ??
        orderData['amount'] ??
        orderData['data']?['total_sum'] ??
        orderData['data']?['total_amount'] ??
        orderData['data']?['amount'] ??
        'Не указана';

    return amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    final amount = _getOrderAmount();

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Способ оплаты', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: _isLoading ? null : _loadCards,
          ),
        ],
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                children: [
                  _amountHeader(amount),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoading ? const Center(child: CircularProgressIndicator(color: AppColors.orange)) : _cardsSection(),
                  ),
                  const SizedBox(height: 16),
                  _payButton(),
                  const SizedBox(height: 14),
                  _footerBadge(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountHeader(String amount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [AppColors.bgTop, AppColors.cardDark]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Сумма к оплате:', style: TextStyle(color: AppColors.textMute, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              text: amount,
              style: const TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w900),
              children: const [
                TextSpan(text: ' ₸', style: TextStyle(color: AppColors.orange, fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardsSection() {
    if (_cards == null || _cards!.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_off_outlined, color: AppColors.textMute.withValues(alpha: 0.8), size: 56),
          const SizedBox(height: 12),
          const Text('Карт пока нет', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Добавьте карту, чтобы оплатить заказ', style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.9))),
          const SizedBox(height: 16),
          _addCardButton(expanded: false),
        ],
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        if (index == _cards!.length) {
          return _addCardButton();
        }
        final card = _cards![index];
        return _cardTile(card);
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: _cards!.length + 1,
    );
  }

  Widget _cardTile(Map<String, dynamic> card) {
    final id = card['halyk_id']?.toString();
    final mask = card['card_mask']?.toString() ?? 'Неизвестная карта';
    final holder = card['payer_name']?.toString();
    final bool isSelected = _selectedCardId == id;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCardId = id;
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: isSelected
                ? [AppColors.cardDark, AppColors.blue]
                : [AppColors.cardDark.withValues(alpha: 0.9), AppColors.card.withValues(alpha: 0.9)],
          ),
          border: Border.all(color: isSelected ? AppColors.orange.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 12)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? AppColors.orange : Colors.white.withValues(alpha: 0.4), width: 2),
                color: isSelected ? AppColors.orange : Colors.transparent,
              ),
              child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.black) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mask, style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(holder?.isNotEmpty == true ? holder! : 'Банковская карта',
                      style: const TextStyle(color: AppColors.textMute, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white.withValues(alpha: 0.02),
      ),
      onPressed: _addCard,
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  Widget _payButton() {
    final bool disabled = _isLoading || _isPaying || _selectedCardId == null;
    return GestureDetector(
      onTap: disabled ? null : _pay,
      child: Opacity(
        opacity: disabled ? 0.6 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(colors: [Color(0xFF8B1F1E), AppColors.red]),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isPaying) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                ),
                const SizedBox(width: 10),
              ] else
                const Icon(Icons.lock_outline, color: Colors.white, size: 18),
              const Text('Оплатить', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerBadge() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(height: 4),
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.transparent,
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.black,
            child: Text('24', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800)),
          ),
        ),
        SizedBox(height: 10),
        Text('ВСЕГДА В ВАШЕМ КРУГУ', style: TextStyle(color: AppColors.orange, fontSize: 11, fontWeight: FontWeight.w800)),
        SizedBox(height: 4),
        Text('ӘРҚАШАН СІЗДІҢ АРАҢЫЗДА', style: TextStyle(color: AppColors.textMute, fontSize: 10, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
