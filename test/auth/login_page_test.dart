import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
