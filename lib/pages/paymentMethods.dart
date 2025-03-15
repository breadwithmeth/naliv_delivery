import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/addNewCardPage.dart';

class PaymentMethods extends StatefulWidget {
  const PaymentMethods({super.key});

  @override
  State<PaymentMethods> createState() => _PaymentMethodsState();
}

class _PaymentMethodsState extends State<PaymentMethods> {
  List cards = [];
  _getSavedCards() {
    getSavedCards().then((v) {
      //print(v);
      setState(() {
        cards = v;
      });
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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text("Способы оплаты"),
      ),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
                child: Container(
              margin: EdgeInsets.all(10),
              child: CupertinoButton.filled(
                  child: Text(
                    "Добавить новую карту",
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(context, CupertinoPageRoute(
                      builder: (context) {
                        return AddNewCardPage(
                          createOrder: false,
                        );
                      },
                    ));
                  }),
            )),
          ),
          SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverList.builder(
              itemCount: cards.length,
              itemBuilder: (context, index) {
                return Container(
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cards[index]["mask"]),
                        IconButton(
                            onPressed: () {}, icon: Icon(CupertinoIcons.clear)),
                      ]),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
