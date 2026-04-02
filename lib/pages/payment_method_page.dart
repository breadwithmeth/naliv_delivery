import 'package:flutter/material.dart';
import 'package:gradusy24/shared/app_theme.dart';
import 'package:gradusy24/utils/app_navigator.dart';
import 'package:gradusy24/utils/api.dart';
import 'package:gradusy24/utils/cart_provider.dart';
import 'package:gradusy24/utils/responsive.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentMethodPage extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final double? displayAmount;

  const PaymentMethodPage({Key? key, required this.orderData, this.displayAmount}) : super(key: key);

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
      await _showNotice('Карты не загружены', 'Ошибка загрузки карт: $e');
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
        await _showNotice('Ссылка недоступна', 'Не удалось открыть ссылку для добавления карты.');
      }
    } else {
      if (!mounted) return;
      await _showNotice('Ссылка недоступна', 'Не удалось получить ссылку для добавления карты.');
    }
  }

  Future<void> _pay() async {
    if (_isPaying || _isLoading) return;
    if (_selectedCardId == null) {
      if (mounted) {
        await _showNotice('Карта не выбрана', 'Пожалуйста, выберите карту для оплаты.');
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
      if (orderId == null || orderId.isEmpty) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        if (mounted) {
          await _showNotice('Заказ не найден', 'ID заказа не найден.');
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
          Provider.of<CartProvider>(context, listen: false).clearCart();
          await _showNotice(
            'Оплата прошла',
            'Заказ #$orderId успешно оплачен. Статус: $paymentStatus.',
          );
          await AppNavigator.goToHomeTab(0);
        }
      } else {
        // Ошибка оплаты
        final errorMessage = result['error'] is Map ? result['error']['message'] : result['error'].toString();

        if (mounted) {
          await _showNotice('Ошибка оплаты', 'Ошибка оплаты: $errorMessage');
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        await _showNotice('Ошибка оплаты', 'Произошла ошибка: $e');
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
    if (widget.displayAmount != null) {
      return widget.displayAmount!.toStringAsFixed(0);
    }

    final orderData = widget.orderData;

    // Проверяем различные возможные поля для суммы
    final amount = orderData['payable_amount'] ??
        orderData['final_amount'] ??
        orderData['total_amount'] ??
        orderData['total_sum'] ??
        orderData['amount'] ??
        orderData['cost_summary']?['total_sum'] ??
        orderData['cost_summary']?['total'] ??
        orderData['data']?['total_sum'] ??
        orderData['data']?['total_amount'] ??
        orderData['data']?['amount'] ??
        'Не указана';

    return amount.toString();
  }

  Future<void> _showNotice(String title, String message) {
    return AppDialogs.showMessage(
      context,
      title: title,
      message: message,
    );
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
              padding: EdgeInsets.fromLTRB(14.s, 0, 14.s, 18.s),
              child: Column(
                children: [
                  _amountHeader(amount),
                  SizedBox(height: 14.s),
                  Expanded(
                    child: _isLoading ? const Center(child: CircularProgressIndicator(color: AppColors.orange)) : _cardsSection(),
                  ),
                  SizedBox(height: 14.s),
                  _payButton(),
                  SizedBox(height: 12.s),
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
      padding: EdgeInsets.all(14.s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.s),
        gradient: const LinearGradient(colors: [AppColors.bgTop, AppColors.cardDark]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Сумма к оплате:', style: TextStyle(color: AppColors.textMute, fontSize: 12.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 5.s),
          RichText(
            text: TextSpan(
              text: amount,
              style: TextStyle(color: AppColors.text, fontSize: 20.sp, fontWeight: FontWeight.w900),
              children: [
                TextSpan(text: ' ₸', style: TextStyle(color: AppColors.orange, fontSize: 16.sp, fontWeight: FontWeight.w800)),
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
          Icon(Icons.credit_card_off_outlined, color: AppColors.textMute.withValues(alpha: 0.8), size: 50.s),
          SizedBox(height: 10.s),
          const Text('Карт пока нет', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
          SizedBox(height: 7.s),
          Text('Добавьте карту, чтобы оплатить заказ', style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.9))),
          SizedBox(height: 14.s),
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
      separatorBuilder: (_, __) => SizedBox(height: 10.s),
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
      borderRadius: BorderRadius.circular(16.s),
      child: Container(
        padding: EdgeInsets.all(12.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.s),
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
              width: 24.s,
              height: 24.s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? AppColors.orange : Colors.white.withValues(alpha: 0.4), width: 2),
                color: isSelected ? AppColors.orange : Colors.transparent,
              ),
              child: isSelected ? Icon(Icons.check, size: 14.s, color: Colors.black) : null,
            ),
            SizedBox(width: 12.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mask, style: TextStyle(color: AppColors.text, fontSize: 14.sp, fontWeight: FontWeight.w800)),
                  SizedBox(height: 3.s),
                  Text(holder?.isNotEmpty == true ? holder! : 'Банковская карта',
                      style: TextStyle(color: AppColors.textMute, fontSize: 11.sp, fontWeight: FontWeight.w600)),
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
        padding: EdgeInsets.symmetric(vertical: 12.s, horizontal: 12.s),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.s)),
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
          padding: EdgeInsets.symmetric(vertical: 14.s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.s),
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
                SizedBox(width: 10.s),
              ] else
                Icon(Icons.lock_outline, color: Colors.white, size: 16.s),
              Text('Оплатить', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerBadge() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 4.s),
        CircleAvatar(
          radius: 22.s,
          backgroundColor: Colors.transparent,
          child: CircleAvatar(
            radius: 20.s,
            backgroundColor: Colors.black,
            child: Text('24', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800)),
          ),
        ),
        SizedBox(height: 9.s),
        Text('ВСЕГДА В ВАШЕМ КРУГУ', style: TextStyle(color: AppColors.orange, fontSize: 10.sp, fontWeight: FontWeight.w800)),
        SizedBox(height: 3.s),
        Text('ӘРҚАШАН СІЗДІҢ АРАҢЫЗДА', style: TextStyle(color: AppColors.textMute, fontSize: 9.sp, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
