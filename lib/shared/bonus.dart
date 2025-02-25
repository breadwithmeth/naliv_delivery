import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:naliv_delivery/misc/api.dart';

class BonusWidget extends StatefulWidget {
  const BonusWidget({super.key});

  @override
  State<BonusWidget> createState() => _BonusWidgetState();
}

class _BonusWidgetState extends State<BonusWidget> {
  bool showbarcode = false;
  int? amount = null;
  String card_uuid = "";
  _getBonuses() {
    getBonuses().then((value) {
      print(value);
      if (mounted) {
        setState(() {
          amount = int.parse(value["amount"]);
          card_uuid = value["card_uuid"];
        });
      }
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getBonuses();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.all(0),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
            color: Colors.deepOrange,
            borderRadius: BorderRadius.all(Radius.circular(30))),
        child: AnimatedMeshGradient(
            colors: [
              Colors.deepOrangeAccent.shade700,
              Colors.deepOrange,
              Colors.black,
              Colors.amber.shade900
            ],
            options: AnimatedMeshGradientOptions(
                frequency: 5, amplitude: 50, speed: 1),
            child: AnimatedCrossFade(
                alignment: Alignment.bottomCenter,
                firstChild: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      boxShadow: [
                        // BoxShadow(
                        //     color: Colors.white.withOpacity(0.5),
                        //     blurRadius: 10,
                        //     spreadRadius: 5)
                      ],
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                    child: GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) {
                            return Container(
                              padding: EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(30))),
                              height: 500,
                              child: Column(
                                children: [
                                  BarcodeWidget(
                                    barcode: Barcode.code128(),
                                    data: card_uuid,
                                    drawText: false,
                                  ),
                                  Text(
                                    "Покажите код сотруднику магазина",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black),
                                  ),
                                  Spacer(),
                                  Text(
                                    "Транзакции, связанные с начислением бонусов, могут обрабатываться в течение срока до 24 (двадцати четырех) часов. Для получения предусмотренных подарочных бонусов (при их наличии) Пользователю необходимо предварительно совершить покупку.",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade600),
                                  )
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: FittedBox(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            amount == null
                                ? CircularProgressIndicator()
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      // Image.network(
                                      //   "https://i.ibb.co.com/X2x6QbS/coin.png",
                                      //   height: 48,
                                      // ),

                                      Text(
                                        amount.toString(),
                                        style: GoogleFonts.prostoOne(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.white),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    )),
                secondChild: GestureDetector(
                  onTap: () => setState(() {
                    showbarcode = !showbarcode;
                  }),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      // color: Colors.black.withOpacity(0.8),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.white.withOpacity(1),
                            blurRadius: 10,
                            spreadRadius: 5)
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BarcodeWidget(
                          barcode: Barcode.code128(),
                          data: card_uuid,
                          drawText: false,
                        )
                      ],
                    ),
                  ),
                ),
                crossFadeState: showbarcode
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: Durations.short4)));
  }
}
