import 'dart:async';

import 'dart:ui' show AppLifecycleState;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/ui/app_haptics.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const lightImpact = 'HapticFeedbackType.lightImpact';
const selectionClick = 'HapticFeedbackType.selectionClick';

/// Isolates the cart throttling clock and advances it with widget test frames.
void enableQuantityClicks(WidgetTester tester) {
  final stopwatch = AppHaptics.quantityClickStopwatch;
  AppHaptics.quantityClickStopwatch = tester.binding.clock.stopwatch();
  addTearDown(() => AppHaptics.quantityClickStopwatch = stopwatch);
}

/// Records haptics without a motor; [reply] can simulate a pending or absent
/// platform implementation.
List<Object?> recordHapticCalls(WidgetTester tester,
    {Future<Object?> Function()? reply}) {
  SharedPreferencesAsyncPlatform.instance ??= InMemorySharedPreferencesAsync.empty();
  // A widget-test binding has no foreground Android activity by default.
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  unawaited(AppHaptics.preference.load());
  final calls = <Object?>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) {
    if (call.method == 'HapticFeedback.vibrate') {
      calls.add(call.arguments);
      if (reply != null) return reply();
    }
    return SynchronousFuture<Object?>(null);
  });
  addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}
