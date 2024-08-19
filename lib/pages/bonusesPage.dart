import 'package:naliv_delivery/pages/bonusRules.dart';

import 'package:qr_flutter/qr_flutter.dart';
import '../globals.dart' as globals;
import 'package:flutter/material.dart';

class BonusesPage extends StatefulWidget {
  const BonusesPage({super.key});

  @override
  State<BonusesPage> createState() => _BonusesPageState();
}

class _BonusesPageState extends State<BonusesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30 * globals.scaleParam),
        child: Row(
          children: [
            MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height
                ? Flexible(
                    flex: 2,
                    fit: FlexFit.tight,
                    child: SizedBox(),
                  )
                : SizedBox(),
            Flexible(
              fit: FlexFit.tight,
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    clipBehavior: Clip.antiAlias,
                    isScrollControlled: true,
                    showDragHandle: false,
                    enableDrag: false,
                    useSafeArea: true,
                    backgroundColor: Colors.white,
                    builder: (context) {
                      return BonusQRModalPage();
                    },
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      fit: FlexFit.tight,
                      child: Text(
                        "Показать QR",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 42 * globals.scaleParam,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text("Бонусы"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close),
          )
        ],
      ),
      body: Center(
        child: Column(
          children: [
            Flexible(
              flex: 3,
              fit: FlexFit.tight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    width: constraints.maxWidth * 0.92,
                    margin: EdgeInsets.all(25 * globals.scaleParam),
                    padding: EdgeInsets.all(25 * globals.scaleParam),
                    child: Column(
                      children: [
                        Container(
                          height: 250 * globals.scaleParam,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(15)),
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          child: Text(
                            "${globals.formatCost("14123")} баллов", //! TODO: REMOVE HARDCODED BONUS POINTS VALUE!!!!!!!
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 52 * globals.scaleParam,
                              height: 1.8,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) {
                                  return const BonusRulesPage();
                                },
                              ),
                            );
                          },
                          child: Text(
                            "Правила бонусной системы",
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                              fontSize: 42 * globals.scaleParam,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BonusQRModalPage extends StatefulWidget {
  const BonusQRModalPage({super.key});

  @override
  State<BonusQRModalPage> createState() => _BonusQRModalPageState();
}

class _BonusQRModalPageState extends State<BonusQRModalPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30 * globals.scaleParam),
        child: Row(
          children: [
            MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height
                ? Flexible(
                    flex: 2,
                    fit: FlexFit.tight,
                    child: SizedBox(),
                  )
                : SizedBox(),
            Flexible(
              fit: FlexFit.tight,
              child: ElevatedButton(
                // style: ElevatedButton.styleFrom(
                //   backgroundColor: Theme.of(context).colorScheme.secondary,
                // ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      fit: FlexFit.tight,
                      child: Text(
                        "Обратно",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 42 * globals.scaleParam,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            padding: EdgeInsets.all(50 * globals.scaleParam),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: 65 * globals.scaleParam,
                ),
                Flexible(
                  child: QrImageView(
                    data: 'https://www.example.com',
                    version: QrVersions.auto,
                    size: MediaQuery.sizeOf(context).shortestSide * 0.8, // Size of the QR code
                    eyeStyle: QrEyeStyle(color: Colors.black, eyeShape: QrEyeShape.square),
                    dataModuleStyle: QrDataModuleStyle(color: Colors.black, dataModuleShape: QrDataModuleShape.square),
                  ),
                ),
                Flexible(
                  child: Text(
                    "Покажите QR код продавцу для оплаты бонусами",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 46 * globals.scaleParam,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
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
