import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';

/// Bottles for drinks poured on tap («розлив») that the store did not give a
/// «Литраж» container option. The store sells its bottles as ordinary
/// products («Пластиковая бутылка 1л с крышкой», «…2л…»); the app adds them to
/// the order itself, so the customer always gets — and pays for — a bottle
/// for every litre, the free litre of a promotion included.
@immutable
class DraftBottle {
  const DraftBottle({
    required this.itemId,
    required this.name,
    required this.price,
    required this.litres,
  });

  final int itemId;
  final String name;
  final double price;
  final int litres;

  @override
  bool operator ==(Object other) =>
      other is DraftBottle && other.itemId == itemId;

  @override
  int get hashCode => itemId.hashCode;
}

/// A store's bottles: only 1 л and 2 л are used.
@immutable
class DraftBottleSet {
  const DraftBottleSet({this.oneLitre, this.twoLitre});

  final DraftBottle? oneLitre;
  final DraftBottle? twoLitre;

  bool get isEmpty => oneLitre == null && twoLitre == null;
}

/// Whether [name] is a drink poured on tap that needs bottles from the store
/// (only when the item has no container option of its own).
bool isDraftDrinkName(String name) => name.toLowerCase().contains('розлив');

/// The fewest 2 л and 1 л bottles that hold [litres]: 2 л first, a 1 л for an
/// odd litre; a part litre needs a whole bottle. With only one size in the
/// store, that size does the job.
Map<DraftBottle, int> draftBottlesFor(double litres, DraftBottleSet set) {
  if (!litres.isFinite || litres <= 0.0000001 || set.isEmpty) return const {};
  final whole = (litres - 0.0000001).ceil();
  final one = set.oneLitre;
  final two = set.twoLitre;
  if (two == null) return {one!: whole};
  if (one == null) return {two: (whole / 2).ceil()};
  return {
    if (whole ~/ 2 > 0) two: whole ~/ 2,
    if (whole.isOdd) one: 1,
  };
}

/// The bottle products of each store, read once from the store's catalogue.
class DraftBottleCatalogue {
  DraftBottleCatalogue._();

  static final instance = DraftBottleCatalogue._();

  final _sets = <int, DraftBottleSet>{};
  final _loading = <int, Future<DraftBottleSet?>>{};

  /// The store the cart orders from. Catalogue and promotion items often come
  /// without their store, so their bottles are the cart's store's bottles.
  int? activeStore;

  /// The store whose bottles an item takes: its own, else the cart's. Items
  /// without a store carry 0, which is not a store.
  int? storeOf(int? itemBusinessId) {
    if (itemBusinessId != null && itemBusinessId > 0) return itemBusinessId;
    final active = activeStore;
    return active != null && active > 0 ? active : null;
  }

  /// The store's bottles once read (possibly empty: the store sells none);
  /// null while unknown.
  DraftBottleSet? cached(int businessId) => _sets[businessId];

  /// Reads the store's bottles; concurrent calls share one request. Null on a
  /// failed read, which leaves the store unknown so it can be retried.
  Future<DraftBottleSet?> load(int businessId) {
    final known = _sets[businessId];
    if (known != null) return Future.value(known);
    return _loading[businessId] ??= _read(businessId).whenComplete(() {
      _loading.remove(businessId);
    });
  }

  Future<DraftBottleSet?> _read(int businessId) async {
    try {
      final found = <int, List<DraftBottle>>{};
      var page = 1;
      while (true) {
        final response = await ApiService.searchItemsTyped(
          'бутылка',
          businessId: businessId,
          page: page,
          limit: 100,
        );
        if (response == null || !response.success) return null;
        for (final item in response.data.items) {
          final litres = bottleLitres(item.name);
          if (litres == null ||
              item.visible != 1 ||
              !item.price.isFinite ||
              item.price < 0) {
            continue;
          }
          (found[litres] ??= []).add(DraftBottle(
            itemId: item.itemId,
            name: item.name,
            price: item.price,
            litres: litres,
          ));
        }
        if (!response.data.pagination.hasNextPage) break;
        page++;
      }
      final set = DraftBottleSet(
        oneLitre: _preferCapped(found[1]),
        twoLitre: _preferCapped(found[2]),
      );
      _sets[businessId] = set;
      return set;
    } catch (error) {
      debugPrint('Draft bottles unavailable: $error');
      return null;
    }
  }

  // Dart's `\w` is ASCII-only, so Cyrillic word endings are spelled out.
  static final _bottleName = RegExp(
      r'пластиков[а-яё]*\s+бутылк[а-яё]*\s*(\d+(?:[.,]\d+)?)\s*л',
      caseSensitive: false);

  /// 1 or 2 for «Пластиковая бутылка 1л / 2л …»; anything else is not used.
  static int? bottleLitres(String name) {
    final match = _bottleName.firstMatch(name);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (value == 1) return 1;
    if (value == 2) return 2;
    return null;
  }

  /// The bottle «с крышкой» when the store sells one, else the plain one.
  static DraftBottle? _preferCapped(List<DraftBottle>? bottles) {
    if (bottles == null || bottles.isEmpty) return null;
    return bottles.firstWhere(
      (bottle) => bottle.name.toLowerCase().contains('крышк'),
      orElse: () => bottles.first,
    );
  }

  @visibleForTesting
  void debugSet(int businessId, DraftBottleSet? set) {
    if (set == null) {
      _sets.remove(businessId);
    } else {
      _sets[businessId] = set;
    }
  }
}
