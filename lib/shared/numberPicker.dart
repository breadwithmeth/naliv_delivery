import 'package:flutter/material.dart';

class NumberPicker extends StatefulWidget {
  const NumberPicker({super.key, required this.amount});

  final int amount;

  @override
  State<NumberPicker> createState() => _NumberPickerState();
}

class _NumberPickerState extends State<NumberPicker> {
  final ScrollController _sc = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.2,
      height: MediaQuery.of(context).size.height * 0.2,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
      ),
      child: ListView.builder(
          itemCount: widget.amount,
          controller: _sc,
          itemBuilder: ((context, index) {
            return SizedBox(
                width: double.infinity,
                height: 10,
                child: Text(index.toString()));
          })),
    );
  }
}
