import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class OrganizationSelectPage extends StatefulWidget {
  const OrganizationSelectPage({super.key});

  @override
  State<OrganizationSelectPage> createState() => _OrganizationSelectPageState();
}

class _OrganizationSelectPageState extends State<OrganizationSelectPage> {
  @override
  Widget build(BuildContext context) {
    TextStyle titleStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      color: Theme.of(context).colorScheme.onBackground,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Flexible(
              fit: FlexFit.tight,
              child: Column(
                children: [
                  Flexible(child: Text("Бар-маркеты", style: titleStyle)),
                  Flexible(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 1,
                      itemBuilder: (context, index) {
                        return Container(
                          width: MediaQuery.of(context).size.width * 0.5,
                          height: MediaQuery.of(context).size.height * 0.2,
                          child: Placeholder(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Flexible(
              flex: 5,
              fit: FlexFit.tight,
              child: SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
