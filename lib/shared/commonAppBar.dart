import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../misc/colors.dart';

class CommonAppBar extends StatefulWidget {
  const CommonAppBar(
      {super.key,
      required this.business,
      required this.title,
      required this.titleIcon, required this.options});
  final Map business;
  final String title;
  final Icon titleIcon;
  final List<Widget> options;
  @override
  State<CommonAppBar> createState() => _CommonAppBarState();
}

class _CommonAppBarState extends State<CommonAppBar> {
  Map business = {};
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      business = widget.business;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white70,
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 10,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    widget.titleIcon,
                    SizedBox(
                      width: 5,
                    ),
                    Text(
                      widget.title,
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 20),
                    ),
                  ],
                ),
                SizedBox(
                  height: 5,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      business!["city"],
                      style: TextStyle(fontSize: 12, color: gray1),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 6,
                    ),
                    Text(
                      business!["address"],
                      style: TextStyle(fontSize: 12, color: gray1),
                    )
                  ],
                )
              ],
            ),
            Spacer(),
            Row(children: widget.options),
            SizedBox(
              width: 10,
            ),
          ],
        ),
      ),
    );
  }
}
