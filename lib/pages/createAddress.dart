import 'package:flutter/material.dart';

class CreateAddress extends StatefulWidget {
  const CreateAddress(
      {super.key,
      required this.street,
      required this.appartment,
      required this.lat,
      required this.lon});
  final String street;
  final String appartment;
  final double lat;
  final double lon;
  @override
  State<CreateAddress> createState() => _CreateAddressState();
}

class _CreateAddressState extends State<CreateAddress> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [Text(widget.street), Text(widget.appartment)],
          ),
          Row(
            children: [Text(widget.lat.toString()), SizedBox(width: 10,), Text(widget.lon.toString())],
          ),
        ],
      )),
    );
  }
}
