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
      setState(() {
        amount = int.parse(value["amount"]);
        card_uuid = value["card_uuid"];
      });
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
        margin: EdgeInsets.only(left: 5, right: 5, bottom: 10),
        padding: EdgeInsets.all(0),
        clipBehavior: Clip.hardEdge,
        height: 150,
        decoration: BoxDecoration(
            color: Colors.orangeAccent,
            borderRadius: BorderRadius.all(Radius.circular(30))),
        child: AnimatedMeshGradient(
            colors: [
              Colors.black,
              Colors.deepPurpleAccent.shade700,
              Colors.black,
              Colors.indigo.shade900
            ],
            options: AnimatedMeshGradientOptions(),
            child: AnimatedCrossFade(
                alignment: Alignment.bottomCenter,
                firstChild: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 5)
                      ],
                    ),
                    padding: EdgeInsets.all(10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "Текущий баланс:",
                                  style: GoogleFonts.roboto(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white),
                                ),
                              ],
                            ),
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
                                            fontSize: 48,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.white),
                                      ),
                                      Text(
                                        "Б",
                                        style: GoogleFonts.prostoOne(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white),
                                      ),
                                    ],
                                  )
                          ],
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(Icons.info),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      content: Text(
                                          "Бонусы начисляются в течение 24 часов после покупки. Чтобы использовать бонусы, необходимо предъявить дисконтную карту в магазине. Максимальная сумма, которую можно оплатить бонусами, составляет 30% от стоимости покупки."),
                                    );
                                  },
                                );
                              },
                            ),
                            IconButton(
                                onPressed: () {
                                  setState(() {
                                    showbarcode = !showbarcode;
                                  });
                                },
                                icon: Icon(Icons.qr_code))
                          ],
                        )
                      ],
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
                duration: Durations.medium2)));
  }
}
