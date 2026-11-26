import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../ui/app_haptics.dart';
import '../utils/api.dart';
import '../utils/liked_items_provider.dart';
import '../utils/liked_storage_service.dart';

/// Resolves the same local credential used by [toggleItemLike], once per
/// credential generation and per open screen (not once per result row).
mixin FavoriteSessionVisibility<T extends StatefulWidget> on State<T> {
  AuthSession? _favoriteSession;
  int _favoriteRevision = AuthService.credentialRevision;

  bool get canFavorite => _favoriteSession?.isCurrent == true;

  @override
  void initState() {
    super.initState();
    AuthService.sessionRevision.addListener(_favoriteSessionChanged);
    _resolveFavoriteSession();
  }

  void _favoriteSessionChanged() {
    final revision = AuthService.credentialRevision;
    if (revision == _favoriteRevision) return;
    _favoriteRevision = revision;
    if (_favoriteSession != null) setState(() => _favoriteSession = null);
    _resolveFavoriteSession();
  }

  Future<void> _resolveFavoriteSession() async {
    try {
      final session = await AuthService.captureSession();
      if (mounted && session != null && session.isCurrent) {
        setState(() => _favoriteSession = session);
      }
    } catch (error) {
      // A failed local credential read must not expose an account action.
      debugPrint('Could not resolve favorite availability: ${error.runtimeType}');
    }
  }

  @override
  void dispose() {
    AuthService.sessionRevision.removeListener(_favoriteSessionChanged);
    super.dispose();
  }
}

/// Ends a favorite gesture's route visit when another route becomes topmost.
class FavoriteRouteObserver extends NavigatorObserver {
  static final _visits = Expando<Object>();

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    if (previousTopRoute != null && _visits[previousTopRoute] != null) {
      _visits[previousTopRoute] = null;
    }
  }
}

class _FavoriteGesture with WidgetsBindingObserver {
  _FavoriteGesture(BuildContext context)
      : _context = context,
        _route = ModalRoute.of(context) {
    final route = _route;
    if (route != null &&
        route.isCurrent &&
        _binding.lifecycleState == AppLifecycleState.resumed) {
      _visit = FavoriteRouteObserver._visits[route] ??= Object();
      _binding.addObserver(this);
    }
    AuthService.sessionRevision.addListener(_sessionChanged);
  }

  final BuildContext _context;
  final ModalRoute<dynamic>? _route;
  final _binding = WidgetsBinding.instance;
  final _credentialRevision = AuthService.credentialRevision;
  final _identity = AuthService.currentIdentity;
  Object? _visit;
  bool _stayedForeground = true;
  bool _accountUnchanged = true;

  bool get isCurrentAccount => _accountUnchanged && !AuthService.isEndingSession;

  void _sessionChanged() {
    if (_credentialRevision != AuthService.credentialRevision ||
        _identity != AuthService.currentIdentity) {
      _accountUnchanged = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stayedForeground = false;
  }

  void confirm() {
    final route = _route;
    if (_stayedForeground &&
        _visit != null &&
        _context.mounted &&
        isCurrentAccount &&
        route != null &&
        route.isCurrent &&
        identical(FavoriteRouteObserver._visits[route], _visit)) {
      AppHaptics.selectionConfirmed();
    }
  }

  void dispose() {
    if (_visit != null) _binding.removeObserver(this);
    AuthService.sessionRevision.removeListener(_sessionChanged);
  }
}

/// Toggles a product's favorite flag from the initiating UI [context].
///
/// Confirms a changed state only while that route stays foregrounded and the
/// same account remains active. Persists store-scoped state independently of
/// whether feedback is still relevant. [wasLiked] is the displayed state when
/// the shared membership for this item is unknown.
///
/// Returns the confirmed state, or `null` if it is unconfirmed for the account.
Future<bool?> toggleItemLike(
  BuildContext context, {
  required int? businessId,
  required int itemId,
  bool wasLiked = false,
}) async {
  final provider =
      businessId == null ? null : context.read<LikedItemsProvider?>();
  final gesture = _FavoriteGesture(context);
  try {
    final session = await AuthService.captureSession();
    if (session == null || !gesture.isCurrentAccount) return null;
    final liked = await ApiService.toggleLikeItem(
      itemId,
      credentialToken: session.token,
    );
    if (liked == null || !gesture.isCurrentAccount) return null;
    final previous = businessId == null
        ? wasLiked
        : provider?.confirmedLike(businessId, itemId) ?? wasLiked;
    if (businessId != null) provider?.updateLike(businessId, itemId, liked);
    if (previous != liked) gesture.confirm();
    if (!gesture.isCurrentAccount) return null;
    if (businessId != null) {
      try {
        await LikedStorageService.setLiked(
          businessId: businessId,
          itemId: itemId,
          liked: liked,
        );
      } catch (_) {
        if (context.mounted && gesture.isCurrentAccount) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
            content: Text('Избранное изменено, но не сохранено на устройстве'),
          ));
        }
      }
    }
    return gesture.isCurrentAccount ? liked : null;
  } finally {
    gesture.dispose();
  }
}
