import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LikedStorageService {
  static String _keyForBusiness(int businessId) => 'liked_items_${businessId}';

  static Future<Set<int>> getLikedIds({required int businessId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyForBusiness(businessId));
    if (raw == null || raw.isEmpty) return <int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => int.tryParse(e.toString()) ?? -1)
            .where((e) => e >= 0)
            .toSet();
      }
    } catch (_) {}
    return <int>{};
  }

  static Future<void> _saveLikedIds(int businessId, Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyForBusiness(businessId),
      jsonEncode(ids.toList()),
    );
  }

  static Future<void> setLiked({
    required int businessId,
    required int itemId,
    required bool liked,
  }) async {
    final ids = await getLikedIds(businessId: businessId);
    if (liked) {
      ids.add(itemId);
    } else {
      ids.remove(itemId);
    }
    await _saveLikedIds(businessId, ids);
  }

  static Future<bool> isLiked({
    required int businessId,
    required int itemId,
  }) async {
    final ids = await getLikedIds(businessId: businessId);
    return ids.contains(itemId);
  }
}
