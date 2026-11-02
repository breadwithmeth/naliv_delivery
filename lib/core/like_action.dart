import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../utils/api.dart';
import '../utils/liked_items_provider.dart';
import '../utils/liked_storage_service.dart';

/// Toggles a product's favourite flag.
///
/// Publishes the backend-confirmed state, then persists it for the verified
/// account. Local persistence failure is reported without undoing the server.
///
/// Returns the new state, or null when the request failed.
Future<bool?> toggleItemLike(
  BuildContext context, {
  required int businessId,
  required int itemId,
}) async {
  final provider = context.read<LikedItemsProvider>();
  final session = await AuthService.captureSession();
  if (session == null) return null;
  final changed = await ApiService.toggleLikeItem(
    itemId,
    credentialToken: session.token,
  );
  if (changed == null || !session.isCurrent) return null;
  provider.updateLike(businessId, itemId, changed);
  try {
    await LikedStorageService.setLiked(
      businessId: businessId,
      itemId: itemId,
      liked: changed,
    );
  } catch (_) {
    if (context.mounted && session.isCurrent) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
        content: Text('Избранное изменено, но не сохранено на устройстве'),
      ));
    }
  }
  if (!session.isCurrent) return null;
  return changed;
}
