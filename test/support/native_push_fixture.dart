import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Intercepts platform calls before they can reach a native provider SDK.
class NativePushFixture {
  static const _channels = <String>[
    'OneSignal',
    'OneSignal#debug',
    'OneSignal#user',
    'OneSignal#pushsubscription',
    'OneSignal#notifications',
    'OneSignal#inappmessages',
  ];

  final unexpected = <String>[];
  final calls = <String>[];
  final logins = <String>[];
  final effects = <String>[];
  /// The tags the app has put on the device, as the native SDK would hold them.
  final tags = <String, String>{};
  int initializations = 0;
  Future<void> Function()? initialize;
  Future<void> Function(String)? login;
  Future<void> Function()? logout;

  void install() {
    for (final name in _channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              MethodChannel(name), (call) => _respond(name, call));
    }
  }

  void uninstall() {
    for (final name in _channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  }

  Future<Object?> _respond(String channel, MethodCall call) async {
    calls.add('$channel ${call.method}');
    final method = call.method;
    if (channel == 'OneSignal') {
      if (method == 'OneSignal#initialize' &&
          call.arguments is Map &&
          call.arguments['appId'] == '3da3fda3-1598-4617-970f-62621f3263ee') {
        initializations++;
        await initialize?.call();
        return null;
      }
      if (method == 'OneSignal#login' &&
          call.arguments is Map &&
          call.arguments['externalId'] is String) {
        final identity = call.arguments['externalId'] as String;
        logins.add(identity);
        await login?.call(identity);
        effects.add('login:$identity');
        return null;
      }
      if (method == 'OneSignal#logout' && call.arguments == null) {
        await logout?.call();
        effects.add('logout');
        return null;
      }
    }
    if (channel == 'OneSignal#debug' &&
        method == 'OneSignal#setLogLevel' &&
        call.arguments is Map &&
        call.arguments['logLevel'] is int) {
      return null;
    }
    if ({
          'OneSignal#user',
          'OneSignal#pushsubscription',
          'OneSignal#notifications',
          'OneSignal#inappmessages',
        }.contains(channel) &&
        method == 'OneSignal#lifecycleInit' &&
        call.arguments == null) {
      return null;
    }
    if (channel == 'OneSignal#user' &&
        method == 'OneSignal#setLanguage' &&
        call.arguments is Map &&
        call.arguments['language'] == 'ru') {
      return null;
    }
    if (channel == 'OneSignal#user') {
      if (method == 'OneSignal#addTags' && call.arguments is Map) {
        for (final entry in (call.arguments as Map).entries) {
          tags['${entry.key}'] = '${entry.value}';
        }
        return null;
      }
      if (method == 'OneSignal#removeTags' && call.arguments is List) {
        for (final key in call.arguments as List) {
          tags.remove('$key');
        }
        return null;
      }
    }
    if (channel == 'OneSignal#pushsubscription' && call.arguments == null) {
      if (method == 'OneSignal#pushSubscriptionToken') {
        return 'fixture-push-token';
      }
      if (method == 'OneSignal#pushSubscriptionId') {
        return 'fixture-subscription';
      }
      if (method == 'OneSignal#pushSubscriptionOptedIn') return true;
      if (method == 'OneSignal#optIn') return null;
    }
    if (channel == 'OneSignal#notifications' &&
        method == 'OneSignal#permission' &&
        call.arguments == null) {
      return true;
    }
    final rejected = '$channel $method ${call.arguments}';
    if (channel == 'OneSignal#notifications' &&
        method == 'OneSignal#addNativeClickListener' &&
        call.arguments == null) {
      return null;
    }
    unexpected.add(rejected);
    throw StateError('Unexpected native push call: $rejected');
  }
}
