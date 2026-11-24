import 'package:web/web.dart' as web;

/// Whether the web shell owns the startup animation and first-frame handoff.
bool isHtmlSplashManaged() =>
    web.document.documentElement?.hasAttribute('data-html-splash') ?? false;
