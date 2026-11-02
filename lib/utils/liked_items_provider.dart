import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import 'api.dart';

class LikedItemsProvider with ChangeNotifier {
  LikedItemsProvider() : _credentialRevision = AuthService.credentialRevision {
    AuthService.sessionRevision.addListener(_sessionChanged);
  }

  final Map<int, Map<int, bool>> _membership = {};
  final Map<(int, int), int> _changes = {};
  int _revision = 0;
  int _loadGeneration = 0;
  final Map<int, int> _loads = {};
  final Set<int> _loadingBusinesses = {};
  final Set<int> _businesses = {};
  int _credentialRevision;
  String? _error;
  bool _disposed = false;

  bool get isLoading => _loadingBusinesses.isNotEmpty;
  String? get error => _error;

  // An absent entry is unknown, not a confirmed unlike. A paged favorites
  // response can therefore coexist with a partially populated shared cache.
  bool? confirmedLike(int businessId, int itemId) =>
      _membership[businessId]?[itemId];

  bool isLiked(int businessId, int itemId) =>
      confirmedLike(businessId, itemId) == true;

  Set<int> likedItems(int businessId) => {
        for (final entry in _membership[businessId]?.entries ??
            const <MapEntry<int, bool>>[])
          if (entry.value) entry.key,
      };

  void _sessionChanged() {
    if (_credentialRevision == AuthService.credentialRevision) return;
    _credentialRevision = AuthService.credentialRevision;
    clearAll();
    for (final businessId in _businesses) {
      unawaited(loadLiked(businessId));
    }
  }

  Future<void> loadLiked(int businessId) async {
    if (businessId <= 0 || _disposed) return;
    _businesses.add(businessId);
    final generation = ++_loadGeneration;
    _loads[businessId] = generation;
    final started = _revision;
    AuthSession? session;
    try {
      session = await AuthService.captureSession();
      if (session == null || generation != _loads[businessId]) return;
      _loadingBusinesses.add(businessId);
      _error = null;
      notifyListeners();
      final data = await ApiService.getLikedItems(
        businessId: businessId,
        page: 1,
        limit: 500,
        credentialToken: session.token,
      );
      if (!session.isCurrent || generation != _loads[businessId]) return;
      if (data == null) throw StateError('Не удалось загрузить избранное');
      final list = data['items'] ?? data['liked_items'];
      if (list is! List) throw StateError('Некорректный список избранного');
      final membership = <int, bool>{};
      for (final raw in list) {
        if (raw is! Map) continue;
        final id = int.tryParse('${raw['item_id'] ?? raw['itemId'] ?? ''}');
        if (id != null && id > 0) membership[id] = true;
      }
      final current = _membership[businessId];
      for (final change in _changes.entries) {
        if (change.key.$1 == businessId && change.value > started) {
          membership[change.key.$2] = current![change.key.$2]!;
        }
      }
      _membership[businessId] = membership;
    } catch (error) {
      if (session?.isCurrent != true || generation != _loads[businessId]) {
        return;
      }
      _error = error.toString();
    } finally {
      if (session?.isCurrent == true && generation == _loads[businessId]) {
        _loadingBusinesses.remove(businessId);
        notifyListeners();
      }
    }
  }

  void recordLikedPage(int businessId, Iterable<int> itemIds) {
    if (_disposed) return;
    _businesses.add(businessId);
    final membership = _membership.putIfAbsent(businessId, () => {});
    var changed = false;
    for (final itemId in itemIds) {
      if (!membership.containsKey(itemId)) {
        membership[itemId] = true;
        _changes[(businessId, itemId)] = ++_revision;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void updateLike(int businessId, int itemId, bool isLiked) {
    if (_disposed) return;
    _businesses.add(businessId);
    final membership = _membership.putIfAbsent(businessId, () => {});
    _changes[(businessId, itemId)] = ++_revision;
    if (membership[itemId] == isLiked) return;
    membership[itemId] = isLiked;
    notifyListeners();
  }

  void clearBusiness(int businessId) {
    _businesses.remove(businessId);
    _loads.remove(businessId);
    _membership.remove(businessId);
    _changes.removeWhere((key, _) => key.$1 == businessId);
    _loadingBusinesses.remove(businessId);
    notifyListeners();
  }

  void clearAll() {
    _loads.clear();
    _membership.clear();
    _changes.clear();
    _loadingBusinesses.clear();
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loads.clear();
    AuthService.sessionRevision.removeListener(_sessionChanged);
    super.dispose();
  }
}
