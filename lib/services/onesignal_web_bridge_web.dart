import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class OneSignalWebBridge {
  static const Duration _timeout = Duration(seconds: 10);
  static JSExportedDartFunction? _changeHandler;

  static JSObject? get _bridge {
    final bridge = globalContext['GradusyOneSignal'];
    if (bridge == null) return null;
    return bridge as JSObject;
  }

  static Future<T?> _call<T>(
    String method, [
    List<Object?> args = const <Object?>[],
  ]) async {
    final bridge = _bridge;
    if (bridge == null) return null;

    try {
      final result = bridge.callMethodVarArgs<JSAny?>(
        method.toJS,
        args.map((arg) => arg.jsify()).toList(),
      );
      if (result == null) return null;

      final value = await (result as JSPromise<JSAny?>).toDart.timeout(
            _timeout,
          );
      return value.dartify() as T?;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> initialize() async =>
      (await _call<bool>('init')) ?? false;

  static Future<bool> requestPermission() async =>
      (await _call<bool>('requestPermission')) ?? false;

  static Future<String?> getSubscriptionId() async =>
      _call<String>('getSubscriptionId');

  static Future<String?> getPushToken() async => _call<String>('getPushToken');

  static Future<String?> getOneSignalId() async =>
      _call<String>('getOneSignalId');

  static Future<bool> getPermissionGranted() async =>
      (await _call<bool>('getPermissionGranted')) ?? false;

  static Future<bool> getOptedIn() async =>
      (await _call<bool>('getOptedIn')) ?? false;

  static Future<bool> setChangeHandler(void Function() onChange) async {
    _changeHandler = (() {
      onChange();
    }).toJS;
    return (await _call<bool>(
          'setChangeHandler',
          <Object?>[_changeHandler],
        )) ??
        false;
  }

  static Future<bool> login(String externalId) async =>
      (await _call<bool>('login', <Object?>[externalId])) ?? false;

  static Future<bool> logout() async => (await _call<bool>('logout')) ?? false;

  static Future<bool> addTag(String key, String value) async =>
      (await _call<bool>('addTag', <Object?>[key, value])) ?? false;

  static Future<bool> removeTag(String key) async =>
      (await _call<bool>('removeTag', <Object?>[key])) ?? false;
}
