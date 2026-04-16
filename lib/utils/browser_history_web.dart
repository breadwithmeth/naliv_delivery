import 'dart:async';
import 'dart:html' as html;

typedef BrowserHistoryListener = void Function();

final Map<BrowserHistoryListener, StreamSubscription<html.PopStateEvent>> _listeners =
    <BrowserHistoryListener, StreamSubscription<html.PopStateEvent>>{};
StreamSubscription<html.Event>? _beforeUnloadSubscription;

void browserHistoryPushFragment(String fragment) {
  final nextUrl = _withFragment(fragment);
  if (_normalizedHash() == fragment) {
    return;
  }
  html.window.history.pushState(null, html.document.title, nextUrl);
}

void browserHistoryReplaceFragment(String fragment) {
  html.window.history.replaceState(null, html.document.title, _withFragment(fragment));
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
  html.window.history.back();
}

void browserHistoryEnableExitWarning() {
  _beforeUnloadSubscription ??= html.window.onBeforeUnload.listen((event) {
    final unloadEvent = event as html.BeforeUnloadEvent;
    unloadEvent.preventDefault();
    unloadEvent.returnValue = '';
  });
}

void browserHistoryDisableExitWarning() {
  _beforeUnloadSubscription?.cancel();
  _beforeUnloadSubscription = null;
}

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
