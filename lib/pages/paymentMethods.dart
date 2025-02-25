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
      print(v);
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
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.black,
          ),
          SliverToBoxAdapter(
              child: Container(
            margin: EdgeInsets.all(10),
            child: ElevatedButton(
                child: Text(
                  "Добавить новую карту",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
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
          SliverList.builder(
            itemCount: cards.length,
            itemBuilder: (context, index) {
              return Container(
                margin: EdgeInsets.all(10),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Color(0xFF121212),
                    borderRadius: BorderRadius.all(Radius.circular(15))),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(cards[index]["mask"]),
                      IconButton(onPressed: () {}, icon: Icon(Icons.close))
                    ]),
              );
            },
          ),
        ],
      ),
    );
  }
}
