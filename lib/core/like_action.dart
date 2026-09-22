import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../utils/api.dart';
import '../utils/liked_items_provider.dart';
import '../utils/liked_storage_service.dart';

/// Toggles a product's favourite flag.
///
/// This is the exact flow the old product card ran inline (`shared/product_card.dart:119-136`)
/// and it must stay in one place now that three screens offer the action: call the API first,
/// persist locally, then update the provider — so a failed request never leaves the UI showing
/// a like the backend does not have.
///
/// Returns the new state, or null when the request failed.
Future<bool?> toggleItemLike(
  BuildContext context, {
  required int businessId,
  required int itemId,
}) async {
  final changed = await ApiService.toggleLikeItem(itemId);
  if (changed == null) return null;
  await LikedStorageService.setLiked(
    businessId: businessId,
    itemId: itemId,
    liked: changed,
  );
  if (!context.mounted) return changed;
  context.read<LikedItemsProvider>().updateLike(businessId, itemId, changed);
  return changed;
}
