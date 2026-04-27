typedef BrowserHistoryListener = void Function();

void browserHistoryPushFragment(String fragment) {}

void browserHistoryReplaceFragment(String fragment) {}

String browserHistoryCurrentFragment() => '';

Map<String, String> browserHistoryCurrentQueryParameters() => const <String, String>{};

void browserHistoryPushQueryParameters(Map<String, String> queryParameters) {}

void browserHistoryReplaceQueryParameters(Map<String, String> queryParameters) {}

void browserHistoryBack() {}

void browserHistoryEnableExitWarning() {}

void browserHistoryDisableExitWarning() {}

void browserHistoryListen(BrowserHistoryListener listener) {}

void browserHistoryDispose(BrowserHistoryListener listener) {}
