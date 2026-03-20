// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;

/// Remove the HTML splash overlay on web.
/// Calls the JS removeSplashFromWeb() for a smooth fade-out,
/// falls back to direct DOM removal if the JS function is missing.
void removeHtmlSplash() {
  try {
    js.context.callMethod('removeSplashFromWeb');
  } catch (_) {
    html.document.getElementById('splash')?.remove();
    html.document.getElementById('splash-branding')?.remove();
    html.document.body?.style.background = 'transparent';
  }
}
