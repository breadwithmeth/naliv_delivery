import 'package:flutter/foundation.dart';
import 'api.dart';

class LikedItemsProvider with ChangeNotifier {
  final Map<int, Set<int>> _likedByBusiness =
      {}; // businessId -> set of itemIds
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  bool isLiked(int businessId, int itemId) {
    return _likedByBusiness[businessId]?.contains(itemId) ?? false;
  }

  Set<int> likedItems(int businessId) => _likedByBusiness[businessId] ?? {};

  Future<void> loadLiked(int businessId) async {
    if (businessId <= 0) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiService.getLikedItems(
          businessId: businessId, page: 1, limit: 500);
      final List<dynamic> list = data?['items'] ?? data?['liked_items'] ?? [];
      final set = <int>{};
      for (var raw in list) {
        final id = raw['item_id'] ?? raw['itemId'];
        if (id != null) {
          set.add(int.tryParse(id.toString()) ?? 0);
        }
      }
      _likedByBusiness[businessId] = set;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateLike(int businessId, int itemId, bool isLiked) {
    final set = _likedByBusiness.putIfAbsent(businessId, () => <int>{});
    if (isLiked) {
      set.add(itemId);
    } else {
      set.remove(itemId);
    }
    notifyListeners();
  }

  void clearBusiness(int businessId) {
    _likedByBusiness.remove(businessId);
    notifyListeners();
  }

  void clearAll() {
    _likedByBusiness.clear();
    notifyListeners();
  }
}
