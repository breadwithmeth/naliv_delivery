import 'package:flutter/cupertino.dart';
import 'package:barcode_widget/barcode_widget.dart';
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
    super.initState();
    _getBonuses();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showCupertinoModalPopup(
          context: context,
          builder: (context) => Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 24),
                BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: card_uuid,
                  drawText: false,
                  backgroundColor: CupertinoColors.white,
                  color: CupertinoColors.black,
                  height: 80,
                ),
                SizedBox(height: 16),
                Text(
                  "Покажите код сотруднику магазина",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  "Транзакции могут обрабатываться до 24 часов.\nВы можете оплатить бонусами до 30% от суммы покупки. Однако их использование невозможно для оплаты табачной продукции и упаковки.",
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.activeOrange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.gift_fill,
                  color: CupertinoColors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Бонусы',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            amount == null
                ? CupertinoActivityIndicator(color: CupertinoColors.white)
                : Text(
                    amount.toString(),
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
