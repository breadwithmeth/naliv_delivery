import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/native_push_fixture.dart';

Future<void> _pumpLogin(WidgetTester tester, ThemeData theme) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const LoginPage(),
    ),
  );
  await tester.pump();
}

Future<void> _openPhoneForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-auth-button')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _disposeLogin(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.binding.setSurfaceSize(null);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'successful login returns while optional provider login is pending',
      (tester) async {
    final native = NativePushFixture()..install();
    final pending = Completer<void>();
    native.login = (_) => pending.future;
    final rejected = <String>[];
    final token = 'e30.${base64Url.encode(utf8.encode(jsonEncode({
              'sub': 'user-login'
            }))).replaceAll('=', '')}.fixture';
    SharedPreferences.setMockInitialValues({
      'onesignal_device_id': 'fixture-device',
    });
    addTearDown(() {
      native.uninstall();
      expect(native.unexpected, isEmpty);
      expect(rejected, isEmpty);
    });
    final client = MockClient((request) async {
      if (request.url.origin == 'https://njt25.naliv.kz' &&
          request.url.queryParameters.isEmpty &&
          request.url.fragment.isEmpty) {
        if (request.method == 'POST' &&
            request.url.path == '/api/auth/send-code' &&
            request.headers['authorization'] == null &&
            request.body == jsonEncode({'phone_number': '+77000000000'})) {
          return http.Response('{"success":true}', 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/auth/verify-code' &&
            request.headers['authorization'] == null &&
            request.body ==
                jsonEncode({
                  'phone_number': '+77000000000',
                  'onetime_code': '123456',
                })) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'token': token}
            }),
            202,
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/auth/full-info' &&
            request.headers['authorization'] == 'Bearer $token') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'user': {
                  'id': 'user-login',
                  'name': 'Тестовый Получатель',
                  'date_of_birth': '1990-01-01',
                },
              },
            }),
            200,
            headers: const {
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/users/onesignal-subscription' &&
            request.headers['authorization'] == 'Bearer $token') {
          final body = jsonDecode(request.body);
          if (body is Map &&
              body.length == 7 &&
              body['subscriptionId'] == 'fixture-subscription' &&
              body['externalId'] == 'user-login' &&
              body['deviceId'] == 'fixture-device' &&
              body['deviceType'] == 'android' &&
              body['permissionGranted'] == true &&
              body['optedIn'] == true) {
            return http.Response('{"success":true}', 200);
          }
        }
      }
      rejected.add('${request.method} ${request.url} ${request.body}');
      throw StateError(rejected.last);
    });
    await http.runWithClient(() async {
      var authenticated = false;
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                authenticated = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const LoginPage(
                          startWithPhoneForm: true,
                          completionMode:
                              LoginCompletionMode.returnAuthenticated,
                        ),
                      ),
                    ) ==
                    true;
              },
              child: const Text('Войти для продолжения'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Войти для продолжения'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('auth-phone-input')), '+77000000000');
      await tester.tap(find.byKey(const ValueKey('request-code-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('auth-code-input')), '123456');
      for (var turn = 0; turn < 8; turn++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final completedBeforePush = authenticated;
      pending.complete();
      await tester.pumpAndSettle();
      await _disposeLogin(tester);

      expect(completedBeforePush, isTrue);
      expect(authenticated, isTrue);
    }, () => client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('explicit sign-in opens the phone form and back returns home',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const LoginPage(startWithPhoneForm: true),
            )),
            child: const Text('Открыть вход'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Открыть вход'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Вход по номеру телефона'), findsOneWidget);
    expect(find.text('Персональные акции'), findsNothing);
    await tester.tap(find.byTooltip('Назад'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Открыть вход'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _disposeLogin(tester);
  });

  testWidgets('validates an incomplete phone before any request',
      (tester) async {
    await _pumpLogin(tester, AppTheme.dark());
    await _openPhoneForm(tester);

    await tester.tap(find.byKey(const ValueKey('request-code-button')));
    await tester.pump();

    expect(find.text('Введите номер телефона'), findsOneWidget);
    expect(find.text('Вход по номеру телефона'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _disposeLogin(tester);
  });

  testWidgets('shows the server cooldown without leaving phone entry',
      (tester) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({
          'success': false,
          'message': 'Слишком много запросов',
        }),
        429,
        headers: const {
          'content-type': 'application/json',
          'retry-after': '45',
        },
      );
    });

    await http.runWithClient(() async {
      await _pumpLogin(tester, AppTheme.dark());
      await _openPhoneForm(tester);
      await tester.enterText(
        find.byKey(const ValueKey('auth-phone-input')),
        '+7 700 123 45 67',
      );

      await tester.tap(find.byKey(const ValueKey('request-code-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(requests, hasLength(1));
      expect(find.text('Повторить через 00:45'), findsOneWidget);
      expect(find.text('Вход по номеру телефона'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _disposeLogin(tester);
    }, () => client);
  });

  testWidgets('successful send advances to six-digit verification',
      (tester) async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'success': true, 'message': 'Код отправлен'}),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      await _pumpLogin(tester, AppTheme.dark());
      await _openPhoneForm(tester);
      await tester.enterText(
        find.byKey(const ValueKey('auth-phone-input')),
        '+7 700 123 45 67',
      );

      await tester.tap(find.byKey(const ValueKey('request-code-button')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Введите код'), findsOneWidget);
      expect(find.text('СМС отправлено на +7 700 123 45 67'), findsOneWidget);
      expect(find.text('Проблемы с кодом? Открыть FAQ'), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-code-input')), findsOneWidget);
      expect(find.text('Изменить номер'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _disposeLogin(tester);
    }, () => client);
  });
}
