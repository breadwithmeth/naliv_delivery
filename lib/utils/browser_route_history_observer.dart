import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'browser_history.dart';

class BrowserRouteHistoryObserver extends NavigatorObserver {
  int _routeDepth = 0;
  int _targetBrowserDepth = 0;
  bool _browserPopInProgress = false;
  bool _ignoreNextPopState = false;
  bool _isListening = false;

  void _ensureListening() {
    if (_isListening || !kIsWeb) {
      return;
    }

    browserHistoryListen(_handleBrowserPopState);
    _isListening = true;
  }

  bool _isManagedRoute(Route<dynamic> route) => route is PageRoute<dynamic>;

  int _historyDepth() {
    final query = browserHistoryCurrentQueryParameters();
    return int.tryParse(query['routeDepth'] ?? '') ?? 0;
  }

  void _pushDepthState() {
    final query = Map<String, String>.from(browserHistoryCurrentQueryParameters())..['routeDepth'] = _routeDepth.toString();
    browserHistoryPushQueryParameters(query);
  }

  void _replaceDepthState() {
    final query = Map<String, String>.from(browserHistoryCurrentQueryParameters());
    if (_routeDepth <= 0) {
      query.remove('routeDepth');
    } else {
      query['routeDepth'] = _routeDepth.toString();
    }
    browserHistoryReplaceQueryParameters(query);
  }

  void _handleBrowserPopState() {
    if (_ignoreNextPopState) {
      _ignoreNextPopState = false;
      return;
    }

    final nav = navigator;
    if (nav == null) {
      return;
    }

    final targetDepth = _historyDepth();
    if (targetDepth >= _routeDepth) {
      return;
    }

    _browserPopInProgress = true;
    _targetBrowserDepth = targetDepth;
    if (nav.canPop()) {
      nav.pop();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (!_isManagedRoute(route)) {
      return;
    }

    _ensureListening();

    if (previousRoute == null) {
      _routeDepth = 0;
      _replaceDepthState();
      return;
    }

    _routeDepth += 1;
    if (_browserPopInProgress) {
      _replaceDepthState();
      return;
    }

    _pushDepthState();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (!_isManagedRoute(route)) {
      return;
    }

    if (_routeDepth > 0) {
      _routeDepth -= 1;
    }

    if (_browserPopInProgress) {
      if (_routeDepth > _targetBrowserDepth && navigator?.canPop() == true) {
        scheduleMicrotask(() {
          if (navigator?.canPop() == true) {
            navigator?.pop();
          }
        });
        return;
      }

      _browserPopInProgress = false;
      _replaceDepthState();
      return;
    }

    if (!kIsWeb) {
      return;
    }

    _ignoreNextPopState = true;
    browserHistoryBack();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (!_isManagedRoute(route)) {
      return;
    }

    if (_routeDepth > 0) {
      _routeDepth -= 1;
    }
    _replaceDepthState();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null && _isManagedRoute(newRoute)) {
      _ensureListening();
    }
    _replaceDepthState();
  }
}
