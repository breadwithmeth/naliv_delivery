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

  /// The readable label, including the parent for otherwise ambiguous leaves.
  String get label => needsParentContext && parentName != null
      ? '$name · $parentName'
      : name;
}

@immutable
class SupercategoryView {
  const SupercategoryView({
    required this.id,
    required this.name,
    required this.categories,
    required this.leaves,
    this.description,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String? description;
  final String? imageUrl;

  /// The complete category tree, in the API's order.
  final List<CategoryRef> categories;

  /// The navigable leaves, retaining their own IDs and parent context.
  final List<CategoryRef> leaves;
}
