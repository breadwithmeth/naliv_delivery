// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Remove the HTML splash overlay on web.
void removeHtmlSplash() {
  html.document.getElementById('splash')?.remove();
  html.document.getElementById('splash-branding')?.remove();
  html.document.body?.style.background = 'transparent';
}
