import 'package:web/web.dart' as web;

Object? reserveWebNamedWindow(String windowName) {
  return web.window.open('about:blank', windowName);
}

bool navigateReservedWebWindow(
  Object? windowHandle,
  String url, {
  required String windowName,
}) {
  if (windowHandle != null) {
    try {
      final dynamic reservedWindow = windowHandle;
      reservedWindow.location.replace(url);
      return true;
    } catch (_) {
      // Fallback below.
    }
  }

  return web.window.open(url, windowName) != null;
}

void closeReservedWebWindow(Object? windowHandle) {
  if (windowHandle == null) return;

  try {
    final dynamic reservedWindow = windowHandle;
    reservedWindow.close();
  } catch (_) {}
}
