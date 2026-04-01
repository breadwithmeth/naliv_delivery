import 'package:web/web.dart' as web;

/// Remove the HTML splash overlay on web.
void removeHtmlSplash() {
  web.document.getElementById('splash')?.remove();
  web.document.getElementById('splash-branding')?.remove();
  web.document.body?.style.background = 'transparent';
}
