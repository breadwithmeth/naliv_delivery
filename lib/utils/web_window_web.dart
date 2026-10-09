import 'package:web/web.dart' as web;

Object? reserveWebNamedWindow(String windowName) {
  try {
    final window = web.window.open('about:blank', windowName);
    return window == null || window.closed ? null : window;
  } catch (_) {
    return null;
  }
}

bool navigateReservedWebWindow(
  Object? windowHandle,
  String url, {
  required String windowName,
}) {
  if (windowHandle == null) return false;
  try {
    final reservedWindow = windowHandle as web.Window;
    if (reservedWindow.closed) return false;
    reservedWindow.location.replace(url);
    return !reservedWindow.closed;
  } catch (_) {
    // Never reopen after await: only an explicit user gesture can reserve a
    // replacement window for the same already-accepted link.
    return false;
  }
}

void closeReservedWebWindow(Object? windowHandle) {
  if (windowHandle == null) return;

  try {
    final reservedWindow = windowHandle as web.Window;
    reservedWindow.close();
  } catch (_) {}
}
