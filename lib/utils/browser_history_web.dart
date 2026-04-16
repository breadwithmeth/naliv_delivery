import 'dart:async';
import 'dart:html' as html;

typedef BrowserHistoryListener = void Function();

final Map<BrowserHistoryListener, StreamSubscription<html.PopStateEvent>> _listeners =
    <BrowserHistoryListener, StreamSubscription<html.PopStateEvent>>{};

void browserHistoryPushFragment(String fragment) {
  final nextUrl = _withFragment(fragment);
  if (_normalizedHash() == fragment) {
    return;
  }
  html.window.history.pushState(null, html.document.title ?? '', nextUrl);
}

void browserHistoryReplaceFragment(String fragment) {
  html.window.history.replaceState(null, html.document.title ?? '', _withFragment(fragment));
}

String browserHistoryCurrentFragment() => _normalizedHash();

void browserHistoryListen(BrowserHistoryListener listener) {
  _listeners[listener]?.cancel();
  _listeners[listener] = html.window.onPopState.listen((_) => listener());
}

void browserHistoryDispose(BrowserHistoryListener listener) {
  _listeners.remove(listener)?.cancel();
}

String _normalizedHash() {
  final hash = html.window.location.hash;
  if (hash.isEmpty) {
    return '';
  }
  return hash.startsWith('#') ? hash.substring(1) : hash;
}

String _withFragment(String fragment) {
  final path = html.window.location.pathname;
  final search = html.window.location.search;
  if (fragment.isEmpty) {
    return '$path$search';
  }
  return '$path$search#$fragment';
}
