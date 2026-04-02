import 'package:flutter/material.dart';
import 'package:naliv_delivery/services/sentry_service.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentMethodPage extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const PaymentMethodPage({super.key, required this.orderData});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> with WidgetsBindingObserver {
  List<Map<String, dynamic>>? _cards;
  bool _isLoading = true;
  String? _selectedCardId;
  bool _awaitingCardAdd = false;

  @override
  void initState() {
    super.initState();
    debugPrint('Order data received: ${widget.orderData}');
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadCards();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingCardAdd) {
      // Возвратились из внешнего браузера — обновляем карты один раз
      _awaitingCardAdd = false;
      _loadCards();
    }
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final cards = await ApiService.getUserCards(source: 'halyk');
      if (!mounted) return;
      debugPrint('Loaded cards: $cards');
      setState(() {
        _cards = cards;
        _isLoading = false;
        if (_cards != null && _cards!.isNotEmpty) {
          _selectedCardId = _cards!.first['halyk_id'].toString();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('Ошибка загрузки карт: $e')));
    }
  }

  Future<void> _addCard() async {
    final messenger = ScaffoldMessenger.of(context);
    await SentryService.addBreadcrumb(category: 'payment', message: 'Add card flow started', data: const {'source': 'payment_method_page'});
    final link = await ApiService.generateAddCardLink();
    if (!mounted) return;
    debugPrint('Generated link for adding card: $link');
    if (link != null) {
      final uri = Uri.parse(link);
      if (await canLaunchUrl(uri)) {
        if (!mounted) return;
        _awaitingCardAdd = true;
        await SentryService.addBreadcrumb(
          category: 'payment',
          message: 'Add card link opened in external browser',
          data: const {'launch_mode': 'external_application'},
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await SentryService.captureBusinessFailure(
          message: 'Add card link could not be launched',
          category: 'payment.cards',
          level: SentryLevel.warning,
          tags: const {'flow': 'payment', 'step': 'add_card_browser_launch'},
        );
        messenger.showSnackBar(const SnackBar(content: Text('Не удалось открыть ссылку для добавления карты')));
      }
    } else {
      await SentryService.captureBusinessFailure(
        message: 'Add card link was not generated',
        category: 'payment.cards',
        level: SentryLevel.warning,
        tags: const {'flow': 'payment', 'step': 'add_card_link_missing'},
      );
      messenger.showSnackBar(const SnackBar(content: Text('Не удалось получить ссылку для добавления карты')));
    }
  }

  Future<void> _pay() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_selectedCardId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Пожалуйста, выберите карту для оплаты')));
      return;
    }

    await SentryService.addBreadcrumb(
      category: 'payment',
      message: 'Payment submission started',
      data: {'cards_count': _cards?.length ?? 0, 'has_selected_card': _selectedCardId != null},
    );
    if (!mounted) return;

    // Показываем индикатор загрузки
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final orderId = widget.orderData['order_id']?.toString() ?? widget.orderData['order_uuid']?.toString();
      if (orderId == null) {
        navigator.pop();
        messenger.showSnackBar(const SnackBar(content: Text('Ошибка: ID заказа не найден')));
        return;
      }

      final result = await ApiService.payOrder(orderId, _selectedCardId!);
      if (!mounted) return;

      navigator.pop();

      if (result['success'] == true) {
        // Успешная оплата
        final paymentData = result['data'];
        final paymentStatus = paymentData['payment_status'];

        await SentryService.addBreadcrumb(
          category: 'payment',
          message: 'Payment completed successfully',
          data: {'payment_status': paymentStatus?.toString() ?? 'unknown'},
        );

        messenger.showSnackBar(SnackBar(content: Text('Оплата успешно проведена! Статус: $paymentStatus'), backgroundColor: Colors.green));

        // Возвращаемся на главную страницу после успешной оплаты
        navigator.popUntil((route) => route.isFirst);
      } else {
        // Ошибка оплаты
        final errorMessage = result['error'] is Map ? result['error']['message'] : result['error'].toString();

        await SentryService.addBreadcrumb(
          category: 'payment',
          message: 'Payment returned failure',
          data: {'status_code': result['statusCode']},
          level: SentryLevel.warning,
          type: 'error',
        );

        messenger.showSnackBar(SnackBar(content: Text('Ошибка оплаты: $errorMessage'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      navigator.pop();
      await SentryService.captureBusinessFailure(
        message: 'Payment flow threw an unexpected UI exception',
        category: 'payment.submit',
        tags: const {'flow': 'payment', 'step': 'ui_pay'},
      );
      messenger.showSnackBar(SnackBar(content: Text('Произошла ошибка: $e'), backgroundColor: Colors.red));
    }
  }

  /// Получить сумму заказа из различных возможных полей
  String _getOrderAmount() {
    final orderData = widget.orderData;

    // Проверяем различные возможные поля для суммы
    final amount =
        orderData['total_sum'] ??
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Способ оплаты'),
        actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: 'Обновить', onPressed: _isLoading ? null : () => _loadCards())],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Сумма к оплате: ${_getOrderAmount()} ₸',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  if (_cards != null && _cards!.isNotEmpty)
                    ..._cards!.map((card) {
                      final cardId = card['halyk_id'].toString();
                      final isSelected = _selectedCardId == cardId;
                      return Card(
                        child: ListTile(
                          onTap: () {
                            setState(() {
                              _selectedCardId = cardId;
                            });
                          },
                          leading: Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off),
                          title: Text(card['card_mask'] ?? 'Неизвестная карта'),
                          subtitle: Text(card['payer_name']?.isNotEmpty == true ? card['payer_name'] : 'Банковская карта'),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                        ),
                      );
                    }),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Добавить новую карту'), onPressed: _addCard),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _pay,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Оплатить'),
                  ),
                ],
              ),
            ),
    );
  }
}
