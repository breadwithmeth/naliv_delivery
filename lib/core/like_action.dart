import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../utils/api.dart';
import '../utils/liked_items_provider.dart';
import '../utils/liked_storage_service.dart';

/// Toggles a product's favourite flag.
///
/// Updates the backend first, then persists the confirmed state locally and
/// notifies the provider. A failed request leaves the displayed state unchanged.
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
