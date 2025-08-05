import 'package:flutter/material.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentMethodPage extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const PaymentMethodPage({Key? key, required this.orderData})
      : super(key: key);

  @override
  _PaymentMethodPageState createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  List<Map<String, dynamic>>? _cards;
  bool _isLoading = true;
  String? _selectedCardId;

  @override
  void initState() {
    super.initState();
    print('Order data received: ${widget.orderData}');
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final cards = await ApiService.getUserCards(source: 'halyk');
      print(cards);
      setState(() {
        _cards = cards;
        _isLoading = false;
        if (_cards != null && _cards!.isNotEmpty) {
          _selectedCardId = _cards!.first['halyk_id'].toString();
        }
      });
    } catch (e) {
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
    print('Generated link for adding card: $link');
    if (link != null) {
      final uri = Uri.parse(link);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // После возвращения из браузера, перезагружаем список карт
        _loadCards();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Не удалось открыть ссылку для добавления карты')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Не удалось получить ссылку для добавления карты')),
      );
    }
  }

  Future<void> _pay() async {
    if (_selectedCardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите карту для оплаты')),
      );
      return;
    }

    // Показываем индикатор загрузки
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final orderId = widget.orderData['order_id']?.toString() ??
          widget.orderData['order_uuid']?.toString();
      if (orderId == null) {
        Navigator.pop(context); // Закрываем диалог загрузки
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка: ID заказа не найден')),
        );
        return;
      }

      final result = await ApiService.payOrder(orderId, _selectedCardId!);

      Navigator.pop(context); // Закрываем диалог загрузки

      if (result['success'] == true) {
        // Успешная оплата
        final paymentData = result['data'];
        final paymentStatus = paymentData['payment_status'];

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Оплата успешно проведена! Статус: $paymentStatus'),
            backgroundColor: Colors.green,
          ),
        );

        // Возвращаемся на главную страницу после успешной оплаты
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        // Ошибка оплаты
        final errorMessage = result['error'] is Map
            ? result['error']['message']
            : result['error'].toString();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка оплаты: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Закрываем диалог загрузки
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Произошла ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Способ оплаты'),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 20),
                  if (_cards != null && _cards!.isNotEmpty)
                    ..._cards!.map((card) {
                      return Card(
                        child: RadioListTile<String>(
                          title: Text(card['card_mask'] ?? 'Неизвестная карта'),
                          subtitle: Text(card['payer_name']?.isNotEmpty == true
                              ? card['payer_name']
                              : 'Банковская карта'),
                          value: card['halyk_id'].toString(),
                          groupValue: _selectedCardId,
                          onChanged: (value) {
                            setState(() {
                              _selectedCardId = value;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить новую карту'),
                    onPressed: _addCard,
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _pay,
                    child: const Text('Оплатить'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
