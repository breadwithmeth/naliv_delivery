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
        Navigator.push(context, CupertinoPageRoute(
          builder: (context) {
            return SearchPage(business: widget.business);
          },
        ));
      },
      child: Container(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 2, horizontal: 10),
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Color(0xFF121212),
              borderRadius: BorderRadius.all(
                Radius.circular(100),
              )),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                size: 24,
              ),
              SizedBox(
                width: 10,
              ),
              Text(
                "Поиск",
                style: TextStyle(fontSize: 20),
              )
            ],
          ),
        ),
      ),
    );
  }
}
