typedef BrowserHistoryListener = void Function();

void browserHistoryPushFragment(String fragment) {}

void browserHistoryReplaceFragment(String fragment) {}

String browserHistoryCurrentFragment() => '';

void browserHistoryListen(BrowserHistoryListener listener) {}

void browserHistoryDispose(BrowserHistoryListener listener) {}
