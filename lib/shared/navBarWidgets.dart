import 'package:flutter/cupertino.dart';
import 'package:naliv_delivery/shared/bonus.dart';

class NavBarLeadingWidget extends StatelessWidget {
  const NavBarLeadingWidget({
    Key? key,
    required this.currentAddress,
    required this.addresses,
    this.business,
  }) : super(key: key);

  final Map currentAddress;
  final List addresses;
  final Map? business;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BonusButton(),
        SizedBox(width: 8),
        AddressButton(
          currentAddress: currentAddress,
          addresses: addresses,
          business: business,
        ),
      ],
    );
  }
}

class BonusButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(20),
      ),
      child: BonusWidget(),
    );
  }
}

class AddressButton extends StatelessWidget {
  const AddressButton({
    Key? key,
    required this.currentAddress,
    required this.addresses,
    this.business,
  }) : super(key: key);

  final Map currentAddress;
  final List addresses;
  final Map? business;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              currentAddress["address"] ?? "Выберите адрес",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_down,
            size: 14,
          ),
        ],
      ),
    );
  }
}