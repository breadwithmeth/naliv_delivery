// class CartItem {
//   final int itemId;
//   final String name;
//   final String img;
//   final double basePrice;
//   final String unit;
//   double quantity;
//   final List<SelectedVariant> selectedVariants;
//   final List<Promotion> promotions;

//   CartItem({
//     required this.itemId,
//     required this.name,
//     required this.img,
//     required this.basePrice,
//     required this.unit,
//     required this.quantity,
//     required this.selectedVariants,
//     required this.promotions,
//   });

//   double get unitPrice {
//     double variantTotal = selectedVariants.fold(0.0, (sum, v) => sum + v.variant.price);
//     return basePrice + variantTotal;
//   }

//   double get discountedTotalPrice {
//     double pricePerUnit = unitPrice;
//     int qty = quantity.round();

//     double totalPrice = pricePerUnit * qty;

//     for (var promo in promotions) {
//       if (promo.type == 'SUBTRACT' && promo.baseAmount > 0 && promo.addAmount > 0) {
//         int groupCount = qty ~/ promo.baseAmount;
//         int freeItems = groupCount * promo.addAmount;
//         int payableQty = qty - freeItems;
//         totalPrice = pricePerUnit * payableQty;
//       } else if (promo.type == 'DISCOUNT' && promo.discount != null) {
//         double discountPercent = promo.discount!;
//         totalPrice = totalPrice * (1 - discountPercent / 100);
//       }
//     }

//     return totalPrice;
//   }

//   factory CartItem.fromJson(Map<String, dynamic> json) {
//     return CartItem(
//       itemId: json['item_id'],
//       name: json['name'],
//       img: json['img'],
//       basePrice: (json['base_price'] as num).toDouble(),
//       unit: json['unit'],
//       quantity: (json['quantity'] as num).toDouble(),
//       selectedVariants: (json['selected_variants'] as List<dynamic>?)
//               ?.map((v) => SelectedVariant.fromJson(v))
//               .toList() ??
//           [],
//       promotions: (json['promotions'] as List<dynamic>?)
//               ?.map((p) => Promotion.fromJson(p))
//               .toList() ??
//           [],
//     );
//   }

//   Map<String, dynamic> toJson() => {
//         'item_id': itemId,
//         'name': name,
//         'img': img,
//         'base_price': basePrice,
//         'unit': unit,
//         'quantity': quantity,
//         'selected_variants': selectedVariants.map((v) => v.toJson()).toList(),
//         'promotions': promotions.map((p) => p.toJson()).toList(),
//       };
// }

// class SelectedVariant {
//   final int optionId;
//   final String optionName;
//   final Variant variant;

//   SelectedVariant({
//     required this.optionId,
//     required this.optionName,
//     required this.variant,
//   });

//   factory SelectedVariant.fromJson(Map<String, dynamic> json) {
//     return SelectedVariant(
//       optionId: json['option_id'],
//       optionName: json['option_name'],
//       variant: Variant.fromJson(json['variant']),
//     );
//   }

//   Map<String, dynamic> toJson() => {
//         'option_id': optionId,
//         'option_name': optionName,
//         'variant': variant.toJson(),
//       };
// }

// class Variant {
//   final int relationId;
//   final int itemId;
//   final double price;
//   final double parentItemAmount;

//   Variant({
//     required this.relationId,
//     required this.itemId,
//     required this.price,
//     required this.parentItemAmount,
//   });

//   factory Variant.fromJson(Map<String, dynamic> json) {
//     return Variant(
//       relationId: json['relation_id'],
//       itemId: json['item_id'],
//       price: (json['price'] as num).toDouble(),
//       parentItemAmount: (json['parent_item_amount'] as num).toDouble(),
//     );
//   }

//   Map<String, dynamic> toJson() => {
//         'relation_id': relationId,
//         'item_id': itemId,
//         'price': price,
//         'parent_item_amount': parentItemAmount,
//       };
// }

// class Promotion {
//   final String name;
//   final int baseAmount;
//   final int addAmount;
//   final String type;
//   final double? discount;
//   final String? description;

//   Promotion({
//     required this.name,
//     required this.baseAmount,
//     required this.addAmount,
//     required this.type,
//     this.discount,
//     this.description,
//   });

//   factory Promotion.fromJson(Map<String, dynamic> json) {
//     return Promotion(
//       name: json['name'],
//       baseAmount: json['base_amount'] ?? 0,
//       addAmount: json['add_amount'] ?? 0,
//       type: json['type'],
//       discount: json['discount'] != null ? (json['discount'] as num).toDouble() : null,
//       description: json['description'],
//     );
//   }

//   Map<String, dynamic> toJson() => {
//         'name': name,
//         'base_amount': baseAmount,
//         'add_amount': addAmount,
//         'type': type,
//         'discount': discount,
//         'description': description,
//       };
// }
