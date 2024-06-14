// import 'package:flutter/material.dart';
// import 'package:naliv_delivery/pages/cartPage.dart';
// import 'package:numberpicker/numberpicker.dart';
// import '../misc/api.dart';

// class BuyButton extends StatefulWidget {
//   const BuyButton({super.key, required this.element});
//   final Map<String, dynamic> element;

//   @override
//   State<BuyButton> createState() => _BuyButtonState();
// }

// class _BuyButtonState extends State<BuyButton> {
//   Map element = {};
//   int cacheAmount = 0;

//   Future<void> refreshItemCard() async {
//     if (element["item_id"] != null) {
//       Map<String, dynamic>? element = await getItem(widget.element["item_id"]);
//       setState(() {
//         element = element!;
//       });
//     }
//   }

//   // TODO: Create changeCartAmount inside api.dart
//   // Future<String?> _finalizeCartAmount() async {
//   //   String? finalAmount = await changeCartAmount(element["item_id"], cacheAmount).then(
//   //     (value) {
//   //       print(value);
//   //       return value;
//   //     },
//   //   ).onError(
//   //     (error, stackTrace) {
//   //       throw Exception("buyButton _addToCart failed");
//   //     },
//   //   );
//   // }

//   void _changeCartAmount(int amount) {
//     setState(() {
//       if (amount >= 0) {
//         cacheAmount = amount;
//       }
//     });
//   }

//   void _removeFromCart() {
//     setState(() {
//       if (cacheAmount > 0) {
//         cacheAmount--;
//       }
//     });
//   }

//   void _addToCart() {
//     setState(() {
//       if (cacheAmount < 1000) {
//         cacheAmount++;
//       }
//     });
//   }

//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     // refreshItemCard();
//     setState(() {
//       element = widget.element;
//     });
//   }

//   @override
//   void dispose() {
//     super.dispose();
//     // _finalizeCartAmount.then();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.start,
//       mainAxisSize: MainAxisSize.max,
//       children: [
//         cacheAmount != 0
//             ? Flexible(
//                 child: Container(
//                   decoration: BoxDecoration(
//                       color: Colors.grey.shade100,
//                       borderRadius:
//                           const BorderRadius.all(Radius.circular(10))),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       Flexible(
//                         child: IconButton(
//                           padding: const EdgeInsets.all(0),
//                           onPressed: () {
//                             _removeFromCart();
//                           },
//                           icon: const Icon(Icons.remove),
//                         ),
//                       ),
//                       Flexible(
//                         child: Text(
//                           cacheAmount.toString(),
//                           style: const TextStyle(
//                             color: Colors.black,
//                             fontSize: 16,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ),
//                       Flexible(
//                         child: GestureDetector(
//                           child: IconButton(
//                             padding: const EdgeInsets.all(0),
//                             onPressed: () {
//                               _addToCart();
//                             },
//                             icon: const Icon(Icons.add),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               )
//             : Flexible(
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     shape: const RoundedRectangleBorder(
//                       borderRadius: BorderRadius.all(
//                         Radius.circular(10),
//                       ),
//                     ),
//                     backgroundColor: Theme.of(context).colorScheme.secondary,
//                     disabledBackgroundColor: Theme.of(context)
//                         .colorScheme
//                         .secondary
//                         .withOpacity(0.5),
//                   ),
//                   onPressed: () {
//                     _addToCart();
//                   },
//                   child: const Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     mainAxisSize: MainAxisSize.max,
//                     children: [
//                       FittedBox(
//                         fit: BoxFit.fitWidth,
//                         child: Text(
//                           "В корзину",
//                           style: TextStyle(
//                               fontWeight: FontWeight.w900,
//                               fontSize: 16,
//                               color: Colors.black),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//         // isLoading
//         //     ? Container(
//         //         height: 80,
//         //         color: Colors.white,
//         //         child: GestureDetector(
//         //           onTap: () {
//         //             refreshItemCard();
//         //           },
//         //           child: const Row(
//         //             mainAxisAlignment: MainAxisAlignment.center,
//         //             mainAxisSize: MainAxisSize.max,
//         //             children: [CircularProgressIndicator()],
//         //           ),
//         //         ),
//         //       )
//         //     : Container()
//       ],
//     );
//   }
// }

// class BuyButtonFullWidth extends StatefulWidget {
//   const BuyButtonFullWidth({super.key, required this.element});
//   final Map<String, dynamic> element;

//   @override
//   State<BuyButtonFullWidth> createState() => _BuyButtonFullWidthState();
// }

// class _BuyButtonFullWidthState extends State<BuyButtonFullWidth> {
//   Map element = {};
//   int cacheAmount = 0;
//   bool isNumPickActive = false;
//   bool isAmountConfirmed = false;

//   // TODO: Create changeCartAmount inside api.dart
//   Future<String?> _finalizeCartAmount() async {
//     String? finalAmount = await addToCart(element["item_id"], cacheAmount).then(
//       (value) {
//         print(value);
//         return value;
//       },
//     ).onError(
//       (error, stackTrace) {
//         throw Exception("buyButton _addToCart failed");
//       },
//     );
//   }

//   void _removeFromCart() {
//     setState(() {
//       isAmountConfirmed = false;
//       if (cacheAmount > 0) {
//         cacheAmount--;
//       }
//     });
//   }

//   void _addToCart() {
//     setState(() {
//       isAmountConfirmed = false;
//       if (cacheAmount < 1000) {
//         cacheAmount++;
//       }
//     });
//   }

//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     // refreshItemCard();
//     setState(() {
//       element = widget.element;
//       if (element["amount"] != null) {
//         cacheAmount = int.parse(element["amount"]);
//       } else {
//         cacheAmount = 0;
//       }
//     });
//   }

//   @override
//   void dispose() {
//     super.dispose();
//     // if (element["amount"] != null) {
//     //   if (cacheAmount < int.parse(element["amount"])) {
//     //     _finalizeCartAmount();
//     //   }
//     // } else if (cacheAmount != 0) {
//     //   _finalizeCartAmount();
//     // }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return null;
//   }
// }
