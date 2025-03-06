import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/searchPage.dart';
import 'package:flutter/cupertino.dart';

class Searchwidget extends StatefulWidget {
  const Searchwidget({super.key, required this.business});
  final Map business;

  @override
  State<Searchwidget> createState() => _SearchwidgetState();
}

class _SearchwidgetState extends State<Searchwidget> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => SearchPage(business: widget.business),
          ),
        );
      },
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.search,
              color: CupertinoColors.systemGrey,
              size: 20,
            ),
            SizedBox(width: 6),
            Text(
              "Поиск",
              style: TextStyle(
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
