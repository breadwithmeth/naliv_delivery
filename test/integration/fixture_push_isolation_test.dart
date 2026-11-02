import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/design_surfaces.dart';
import '../support/native_push_fixture.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(surfaceFixturePreferences);
    SurfaceFixtureClient.resetUnexpectedRequests();
  });
  tearDown(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'fixture permission and logout never invoke provider platform SDKs',
      (tester) async {
    final native = NativePushFixture()..install();
    final client = SurfaceFixtureClient();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      native.uninstall();
      client.close();
      expect(native.calls, isEmpty);
      expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const DesignSurfaceApp(
        surface: 'notifications',
        brightness: Brightness.dark,
      ));
      await tester.pumpAndSettle();
      final before = await NotificationService.instance.getPermissionState();
      expect(before.supported, isTrue);
      expect(before.permissionGranted, isFalse);
      expect(before.optedIn, isFalse);
      final permission = find.text('Включить push-уведомления');
      await tester.scrollUntilVisible(permission, 300);
      await tester.tap(permission);
      await tester.pumpAndSettle();
      final after = await NotificationService.instance.getPermissionState();
      expect(after.supported, isTrue);
      expect(after.permissionGranted, isTrue);
      expect(after.optedIn, isTrue);
      expect(native.calls, isEmpty);
      final toast = tester.widget<SnackBar>(find.byType(SnackBar));
      await tester.pump(toast.duration);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpWidget(const DesignSurfaceApp(
        surface: 'profile',
        brightness: Brightness.dark,
      ));
      await tester.pumpAndSettle();
      final logout = find.byKey(const ValueKey('profile-logout'));
      await tester.scrollUntilVisible(logout, 300);
      expect(logout.hitTestable(), findsOneWidget);
      await tester.tap(logout);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Выйти'),
      ));
      await tester.pumpAndSettle();
      expect(await AuthService.captureSession(), isNull);
      expect(native.calls, isEmpty);
    }, () => client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('fixture login completes without native provider SDK work',
      (tester) async {
    final native = NativePushFixture()..install();
    final client = SurfaceFixtureClient();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await AuthService.notifySessionChanged();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      native.uninstall();
      client.close();
      expect(native.calls, isEmpty);
      expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const DesignSurfaceApp(
        surface: 'sign_in',
        brightness: Brightness.dark,
      ));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('auth-phone-input')), '+70000000000');
      await tester.tap(find.byKey(const ValueKey('request-code-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('auth-code-input')), '123456');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auth-code-input')), findsNothing);
      expect(await AuthService.getToken(), 'fixture-only');
      expect(native.calls, isEmpty);
    }, () => client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
