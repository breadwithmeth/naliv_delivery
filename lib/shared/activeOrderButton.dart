import '../globals.dart' as globals;
import 'package:flutter/material.dart';

class ActiveOrdersButton extends StatefulWidget {
  const ActiveOrdersButton({super.key});

  @override
  State<ActiveOrdersButton> createState() => _ActiveOrdersButtonState();
}

class _ActiveOrdersButtonState extends State<ActiveOrdersButton> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200 * globals.scaleParam,
      height: 165 * globals.scaleParam,
    );
  }
}
