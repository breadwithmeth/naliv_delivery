import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import '../../core/product_view.dart';

/// Everything the home screen renders, as plain data.
///
/// The design's home frame shows one specific state (one store, three promo banners, six
/// categories, 164 bonuses). Modelling that as data keeps the layout verifiable against the
/// frame with fixtures, and keeps the screen independent of how the data is fetched.
@immutable
class HomeViewData {
  const HomeViewData({
    required this.storeName,
    required this.storeAddress,
    this.storeId,
    required this.banners,
    required this.promoCard,
    required this.categories,
    this.stores = const [],
    this.activeOrder,
    this.productSections = const [],
    this.signedIn = true,
    this.bonusBalance,
    this.bonusCaption = 'бонусов',
    this.qrCaption = 'Покажите QR на кассе',
    this.bonusCardCode,
  });

  /// Current store (delivery address of the pickup point) shown in the address card.
  final String storeName;
  final String storeAddress;

  /// `businesses[].id` of [storeName] — screens that are still business-scoped need it.
  final int? storeId;

  /// Available stores from the same read-only businesses response.
  final List<HomeStore> stores;
  final HomeActiveOrder? activeOrder;

  final List<HomeBanner> banners;

  /// The large "Кухня" style promo card under the banners.
  final HomePromoCard? promoCard;

  final List<HomeCategory> categories;

  /// Product rows shown below the bonus card in the scrolled home frames.
  final List<HomeProductSection> productSections;

  /// Signed-out state swaps the bonus card for a sign-in prompt.
  final bool signedIn;

  /// Loaded balance; null shows an explicit unavailable state, not a fake zero.
  final num? bonusBalance;
  final String bonusCaption;
  final String qrCaption;

  /// `bonusCard.cardUuid` — the payload the till scans. Null until bonuses have loaded.
  final String? bonusCardCode;
}

@immutable
class HomeActiveOrder {
  const HomeActiveOrder({
    required this.id,
    required this.status,
    required this.source,
  });

  final String id;
  final String status;
  final Map<String, dynamic> source;
}

@immutable
class HomeStore {
  const HomeStore({
    required this.id,
    required this.name,
    required this.address,
    this.city,
  });

  final int id;
  final String name;
  final String address;
  final String? city;
}

@immutable
class HomeBanner {
  const HomeBanner({
    required this.title,
    this.promotionId,
    this.subtitle,
    this.fill,
    this.imageUrl,
  });

  /// Null for design-only placeholders. Never route one to an unrelated offer.
  final int? promotionId;

  final String title;
  final String? subtitle;

  /// Placeholder colour the design uses while artwork is missing.
  final Color? fill;
  final String? imageUrl;
}

@immutable
class HomePromoCard {
  const HomePromoCard({
    required this.id,
    required this.title,
    required this.subtitle,
    this.fill,
    this.imageUrl,
  });

  /// Supercategory id the card opens.
  final int id;
  final String title;
  final String subtitle;
  final Color? fill;
  final String? imageUrl;
}

@immutable
class HomeCategory {
  const HomeCategory({
    required this.id,
    required this.title,
    this.imageUrl,
    this.fill,
  });

  /// Supercategory id the tile opens.
  final int id;
  final String title;
  final String? imageUrl;
  final Color? fill;
}

@immutable
class HomeProductSection {
  const HomeProductSection({
    required this.category,
    required this.products,
  });

  final HomeCategory category;
  final List<ProductView> products;
}
