import '../globals.dart' as globals;
import 'package:flutter/material.dart';

class BonusRulesPage extends StatefulWidget {
  const BonusRulesPage({super.key});

  @override
  State<BonusRulesPage> createState() => _BonusRulesPageState();
}

class _BonusRulesPageState extends State<BonusRulesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Бонусная система"),
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
        child: Text(
          "ЗДЕСЬ ДОЛЖЕН БЫТЬ BonusRules.md",
          style: TextStyle(
            fontSize: 42 * globals.scaleParam,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
