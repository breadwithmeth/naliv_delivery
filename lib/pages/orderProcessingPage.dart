import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/databaseapi.dart';
import 'package:naliv_delivery/shared/openMainPageButton.dart';

class OrderProcessingPage extends StatefulWidget {
  final Map business;
  final bool delivery;
  final String selectedCard;
  final List items;
  final bool useBonuses;
  final String extra;

  const OrderProcessingPage({
    Key? key,
    required this.business,
    required this.delivery,
    required this.selectedCard,
    required this.items,
    required this.useBonuses,
    required this.extra,
  }) : super(key: key);

  @override
  _OrderProcessingPageState createState() => _OrderProcessingPageState();
}

class _OrderProcessingPageState extends State<OrderProcessingPage>
    with SingleTickerProviderStateMixin {
  final DatabaseManager dbm = DatabaseManager();
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _processOrder();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processOrder() async {
    try {
      final businessId = int.parse(widget.business["business_id"].toString());

      var value = await createOrder3(
        widget.business["business_id"],
        widget.delivery ? "1" : "0",
        widget.selectedCard,
        widget.items,
        widget.useBonuses,
        widget.extra,
      );

      // Проверяем success в ответе
      if (value["success"] == false) {
        _showDialog(
          title: "Ошибка",
          content: value["error"] ?? "Произошла ошибка при создании заказа",
          icon: CupertinoIcons.xmark_circle,
          iconColor: CupertinoColors.destructiveRed,
        );
        return;
      }

      // Очищаем корзину только при успешном создании заказа
      await dbm.clearCart(businessId);

      // Проверяем статус оплаты
      if (value["payment_status"] == "insufficent_funds") {
        _showDialog(
          title: "Недостаточно средств",
          content: "Вернитесь на главный экран для повторной оплаты",
          icon: CupertinoIcons.exclamationmark_circle,
          iconColor: CupertinoColors.destructiveRed,
        );
      } else if (value["payment_status"] == "paid") {
        _showDialog(
          title: "Успешно!",
          content:
              "Платёж принят. Вернитесь на главный экран для отслеживания заказа",
          icon: CupertinoIcons.checkmark_circle,
          iconColor: CupertinoColors.activeGreen,
        );
      } else {
        _showDialog(
          title: "Ожидание оплаты",
          content: "Вернитесь на главный экран для просмотра статуса оплаты",
          icon: CupertinoIcons.clock,
          iconColor: CupertinoColors.activeOrange,
        );
      }
    } catch (e) {
      print('Ошибка при обработке заказа: $e');

      _showDialog(
        title: "Ошибка",
        content: "Произошла ошибка при обработке заказа. Попробуйте позже.",
        icon: CupertinoIcons.xmark_circle,
        iconColor: CupertinoColors.destructiveRed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "Обработка заказа",
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: CupertinoColors.systemBackground,
        border: null,
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 100,
              width: 100,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, child) {
                  return Transform.rotate(
                    angle: _controller.value * 2 * 3.14,
                    child: child,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        CupertinoColors.activeBlue,
                        CupertinoColors.systemBlue.withOpacity(0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(25),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        CupertinoColors.white,
                      ),
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 40),
            Text(
              "Пожалуйста, подождите",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
            ),
            SizedBox(height: 12),
            Text(
              "Мы обрабатываем ваш заказ",
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.systemGrey,
              ),
            ),
            SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  _buildOrderInfo(
                    "Сумма заказа",
                    "${_calculateTotal(widget.items)} ₽",
                  ),
                  SizedBox(height: 8),
                  _buildOrderInfo(
                    "Способ получения",
                    widget.delivery ? "Доставка" : "Самовывоз",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfo(String title, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: CupertinoColors.systemGrey,
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotal(List items) {
    return items.fold(0.0,
        (sum, item) => sum + (item['price'] ?? 0) * (item['quantity'] ?? 1));
  }

  void _showDialog({
    required String title,
    required String content,
    required IconData icon,
    required Color iconColor,
  }) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TweenAnimationBuilder(
        duration: Duration(milliseconds: 300),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        builder: (context, double value, child) {
          return Transform.scale(
            scale: value,
            child: CupertinoAlertDialog(
              title: Container(
                padding: EdgeInsets.only(top: 8, bottom: 24),
                child: Column(
                  children: [
                    TweenAnimationBuilder(
                      duration: Duration(milliseconds: 500),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      builder: (context, double value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: iconColor.withOpacity(0.2),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              icon,
                              color: iconColor,
                              size: 45,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 20),
                    Text(
                      title,
                      style: TextStyle(
                        color: CupertinoColors.label,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              content: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.systemGrey,
                    height: 1.3,
                  ),
                ),
              ),
              actions: [
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: CupertinoColors.systemGrey6,
                        width: 1,
                      ),
                    ),
                  ),
                  child: CupertinoDialogAction(
                    child: Text(
                      'Вернуться на главную',
                      style: TextStyle(
                        color: CupertinoColors.activeBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        CupertinoPageRoute(
                            builder: (context) => OpenMainPage()),
                        (route) => false,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
