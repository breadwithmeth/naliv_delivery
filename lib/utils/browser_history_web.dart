import 'dart:async';
import 'package:web/web.dart' as web;

typedef BrowserHistoryListener = void Function();

final Map<BrowserHistoryListener, StreamSubscription<web.PopStateEvent>> _listeners =
    <BrowserHistoryListener, StreamSubscription<web.PopStateEvent>>{};
StreamSubscription<web.BeforeUnloadEvent>? _beforeUnloadSubscription;

void browserHistoryPushFragment(String fragment) {
  final nextUrl = _withFragment(fragment);
  if (_normalizedHash() == fragment) {
    return;
  }
  web.window.history.pushState(null, web.document.title, nextUrl);
}

void browserHistoryReplaceFragment(String fragment) {
  web.window.history.replaceState(null, web.document.title, _withFragment(fragment));
}

String browserHistoryCurrentFragment() => _normalizedHash();

Map<String, String> browserHistoryCurrentQueryParameters() {
  final fragment = browserHistoryCurrentFragment();
  if (fragment.isEmpty) {
    return <String, String>{};
  }

  return Uri.splitQueryString(fragment);
}

void browserHistoryPushQueryParameters(Map<String, String> queryParameters) {
  browserHistoryPushFragment(_buildFragment(queryParameters));
}

void browserHistoryReplaceQueryParameters(Map<String, String> queryParameters) {
  browserHistoryReplaceFragment(_buildFragment(queryParameters));
}

void browserHistoryBack() {
  web.window.history.back();
}

void browserHistoryEnableExitWarning() {
  _beforeUnloadSubscription ??= web.EventStreamProviders.beforeUnloadEvent.forTarget(web.window).listen((event) {
    event.preventDefault();
    event.returnValue = '';
  });
}

void browserHistoryDisableExitWarning() {
  _beforeUnloadSubscription?.cancel();
  _beforeUnloadSubscription = null;
}

void browserHistoryListen(BrowserHistoryListener listener) {
  _listeners[listener]?.cancel();
  _listeners[listener] = web.window.onPopState.listen((_) => listener());
}

void browserHistoryDispose(BrowserHistoryListener listener) {
  _listeners.remove(listener)?.cancel();
}

String _normalizedHash() {
  final hash = web.window.location.hash;
  if (hash.isEmpty) {
    return '';
  }
  return hash.startsWith('#') ? hash.substring(1) : hash;
}

String _withFragment(String fragment) {
  final path = web.window.location.pathname;
  final search = web.window.location.search;
  if (fragment.isEmpty) {
    return '$path$search';
  }
  return '$path$search#$fragment';
}

String _buildFragment(Map<String, String> queryParameters) {
  if (queryParameters.isEmpty) {
    return '';
  }

  final filtered = Map<String, String>.fromEntries(
    queryParameters.entries.where((entry) => entry.key.isNotEmpty && entry.value.isNotEmpty),
  );
  if (filtered.isEmpty) {
    return '';
  }

  return filtered.entries.map((entry) => '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}').join('&');
}
