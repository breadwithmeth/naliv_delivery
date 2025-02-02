import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/paymentMethods.dart';
import 'package:naliv_delivery/shared/openMainPageButton.dart';

class PayForOrderPage extends StatefulWidget {
  const PayForOrderPage({super.key, required this.order_id});
  final String order_id;
  @override
  State<PayForOrderPage> createState() => _PayForOrderPageState();
}

class _PayForOrderPageState extends State<PayForOrderPage> {
  List cards = [];

  void _getSavedCards() async {
    List t_cards = await getSavedCards();
    List _cards = [];
    for (var card in t_cards) {
      _cards.add({
        "card_id": int.parse(card["card_id"]),
        "card_number": card["mask"],
      });
    }

    setState(() {
      cards.addAll(_cards);
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getSavedCards();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.black,
            title: Text("Оплата"),
          ),
          SliverToBoxAdapter(
            child: TextButton(
                onPressed: () {
                  _getSavedCards();
                },
                child: Text("Обновить")),
          ),
          SliverList.builder(
            itemCount: cards.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(cards[index]["card_number"]),
                trailing: TextButton(
                    onPressed: () {
                      pay(widget.order_id.toString(),
                              cards[index]["card_id"].toString())
                          .then((value) {
                        if (value["status"] == "insufficent funds") {
                          showDialog(
                            barrierDismissible: false,
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text(
                                  "Нехватает средств",
                                ),
                                content: Text(
                                    "Вернитесь на главный экран для повторной оплаты"),
                                actions: [OpenMainPage()],
                              );
                            },
                          );
                        } else if (value["code"].toString() == "0") {
                          showDialog(
                            barrierDismissible: false,
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text(
                                  "Платеж принят в обработку",
                                ),
                                content: Text(
                                    "Вернитесь на главный экран для отслеживания заказа"),
                                actions: [OpenMainPage()],
                              );
                            },
                          );
                        } else if (value["status"] == "unknown") {
                          showDialog(
                            barrierDismissible: false,
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text(
                                  "Ожидаем подтверждение платежа от банка",
                                ),
                                content: Text(
                                    "Вернитесь на главный экран для просмотра статуса оплаты"),
                                actions: [OpenMainPage()],
                              );
                            },
                          );
                        }
                      });
                    },
                    child: Text("Выбрать")),
              );
            },
          ),
          SliverToBoxAdapter(
            child: ElevatedButton(
                onPressed: () {
                  Navigator.push(context, CupertinoPageRoute(
                    builder: (context) {
                      return PaymentMethods();
                    },
                  ));
                },
                child: Text("Добавить новую карту")),
          ),
        ],
      ),
    );
  }
}
