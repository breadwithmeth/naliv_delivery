import 'package:flutter/foundation.dart';

/// Store-independent category identities and their original hierarchy.
@immutable
class CategoryRef {
  const CategoryRef({
    required this.id,
    required this.name,
    this.parentId,
    this.parentName,
    this.needsParentContext = false,
    this.description,
    this.imageUrl,
    this.children = const [],
  });

  final int id;
  final String name;
  final int? parentId;
  final String? parentName;
  final bool needsParentContext;
  final String? description;
  final String? imageUrl;
  final List<CategoryRef> children;

  /// Whether this category groups nested categories.
  bool get hasChildren => children.isNotEmpty;

  /// The accessible name. Several parents own a «Светлое», so the parent is spoken with
  /// any name that repeats; the visible navigation is grouped and needs no suffix.
  String get semanticLabel =>
      needsParentContext && parentName != null ? '$name, $parentName' : name;
}

@immutable
class SupercategoryView {
  const SupercategoryView({
    required this.id,
    required this.name,
    required this.categories,
    this.description,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String? description;
  final String? imageUrl;

  /// The category tree in the API's order. The top-level entries are the parent categories
  /// the catalogue is organised by; each one's [CategoryRef.children] are its subcategories.
  final List<CategoryRef> categories;
}
