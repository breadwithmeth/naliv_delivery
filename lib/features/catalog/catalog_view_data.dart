import 'package:flutter/foundation.dart';

/// View models for the catalogue cluster.
///
/// The API's hierarchy is three levels deep — supercategory → category → subcategory — and the
/// design uses two of them:
///
/// * `Каталог` («Слабоалкогольные напитки») lists a supercategory's **subcategories** as
///   sections, with the same names as a jump-to chip strip. Verified against the live API:
///   the design's chips «Аперитив, Белое, Вермут, Винный напиток» are exactly the
///   subcategories of «Вино», which is one of «Слабоалкогольные напитки»'s categories.
/// * `Каталог - Все товары` («Белое») is a single subcategory: a plain grid of its products.
@immutable
class CategoryRef {
  const CategoryRef({required this.id, required this.name});

  final int id;
  final String name;
}

@immutable
class SupercategoryView {
  const SupercategoryView({
    required this.id,
    required this.name,
    required this.subcategories,
    this.description,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String? description;
  final String? imageUrl;

  /// Flattened leaf categories, in the API's own order — the chip strip and the sections.
  final List<CategoryRef> subcategories;
}
