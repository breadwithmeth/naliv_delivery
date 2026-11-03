import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import 'package:naliv_delivery/ui/otp_code_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _codeKey = ValueKey('auth-code-input');

/// Replaces the platform clipboard. [text] null means "empty clipboard".
void _mockClipboard(WidgetTester tester, {String? text}) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      switch (call.method) {
        case 'Clipboard.hasStrings':
          return <String, dynamic>{'value': text != null};
        case 'Clipboard.getData':
          return text == null ? null : <String, dynamic>{'text': text};
      }
      return null;
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
}

Finder _digit(int index, String digit) =>
    find.byKey(ValueKey('otp-digit-$index-$digit'));

TextEditingController _fieldController(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(_codeKey)).controller!;

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.binding.setSurfaceSize(null);
}

class _Harness extends StatefulWidget {
  const _Harness({this.errorText});

  final String? errorText;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final controller = TextEditingController();
  final focusNode = FocusNode();

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: OtpCodeField(
              fieldKey: _codeKey,
              controller: controller,
              focusNode: focusNode,
              errorText: widget.errorText,
            ),
          ),
        ),
      );
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  Size size = const Size(375, 812),
  double textScale = 1,
  String? errorText,
}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: _Harness(errorText: errorText),
  ));
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('OtpCodeFormatter', () {
    const formatter = OtpCodeFormatter(length: 6);

    TextEditingValue edit(String before, String after) =>
        formatter.formatEditUpdate(
          TextEditingValue(
            text: before,
            selection: TextSelection.collapsed(offset: before.length),
          ),
          TextEditingValue(
            text: after,
            selection: TextSelection.collapsed(offset: after.length),
          ),
        );

    test('keeps typed digits and caps the length', () {
      expect(edit('', '1').text, '1');
      expect(edit('12345', '123456').text, '123456');
      expect(edit('123456', '1234567').text, '123456');
    });

    test('drops non-digits typed or pasted', () {
      expect(edit('12', '12a').text, '12');
      expect(edit('', '12-34').text, '1234');
    });

    test('a pasted code with separators or words fills every digit', () {
      expect(edit('', '123 456').text, '123456');
      expect(edit('', '123-456').text, '123456');
      expect(edit('', 'Ваш код: 123456. Никому не сообщайте').text, '123456');
    });

    test('a pasted code replaces a partial or complete one', () {
      expect(edit('12', '12654321').text, '654321');
      expect(edit('123456', '123456654321').text, '654321');
    });

    test('the caret stays at the end', () {
      final value = edit('', '123 456');
      expect(value.selection, const TextSelection.collapsed(offset: 6));
    });

    test('extractOtpCode rejects values that are not a code', () {
      expect(extractOtpCode('+7 777 123 45 67', length: 6), isNull);
      expect(extractOtpCode('1234567', length: 6), isNull);
      expect(extractOtpCode('12345', length: 6), isNull);
      expect(extractOtpCode('Код 654321', length: 6), '654321');
    });
  });

  group('OtpCodeField', () {
    testWidgets('typing fills boxes one by one and backspace removes',
        (tester) async {
      _mockClipboard(tester);
      await _pumpHarness(tester);

      await tester.enterText(find.byKey(_codeKey), '1');
      await tester.pump();
      expect(_digit(0, '1'), findsOneWidget);
      expect(_digit(1, '2'), findsNothing);

      await tester.enterText(find.byKey(_codeKey), '12');
      await tester.pump();
      expect(_digit(1, '2'), findsOneWidget);

      await tester.enterText(find.byKey(_codeKey), '1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_digit(0, '1'), findsOneWidget);
      expect(_digit(1, '2'), findsNothing);
      expect(tester.takeException(), isNull);

      await _dispose(tester);
    });

    testWidgets('a pasted code distributes digits over all six boxes',
        (tester) async {
      _mockClipboard(tester);
      await _pumpHarness(tester);

      await tester.enterText(find.byKey(_codeKey), '482 915');
      await tester.pump(const Duration(milliseconds: 300));

      const digits = '482915';
      for (var i = 0; i < digits.length; i++) {
        expect(_digit(i, digits[i]), findsOneWidget, reason: 'box $i');
      }
      expect(_fieldController(tester).text, digits);
      expect(tester.takeException(), isNull);

      await _dispose(tester);
    });

    testWidgets('the field is one real one-time-code input', (tester) async {
      _mockClipboard(tester);
      await _pumpHarness(tester);

      expect(find.byType(TextField), findsOneWidget);
      final field = tester.widget<TextField>(find.byKey(_codeKey));
      expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
      expect(field.keyboardType, TextInputType.number);
      expect(field.maxLength, 6);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.textInputAction, TextInputAction.done);

      await _dispose(tester);
    });

    testWidgets('tapping a box focuses the field with the caret at the end',
        (tester) async {
      _mockClipboard(tester);
      await _pumpHarness(tester);
      final state = tester.state<_HarnessState>(find.byType(_Harness));

      await tester.enterText(find.byKey(_codeKey), '123');
      await tester.pump();
      state.focusNode.unfocus();
      await tester.pump();
      expect(state.focusNode.hasFocus, isFalse);

      final box =
          tester.getTopLeft(find.byKey(_codeKey)) + const Offset(30, 20);
      await tester.tapAt(box);
      await tester.pump();

      expect(state.focusNode.hasFocus, isTrue);
      expect(
          state.controller.selection, const TextSelection.collapsed(offset: 3));

      await _dispose(tester);
    });

    testWidgets('shows the error text and a live-region for assistive tech',
        (tester) async {
      _mockClipboard(tester);
      await _pumpHarness(tester, errorText: 'Неверный код');
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Неверный код'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _dispose(tester);
    });

    for (final theme in [AppTheme.dark(), AppTheme.light()]) {
      testWidgets(
          'fits 320 px at 2x text without overflow '
          '(${theme.brightness.name})', (tester) async {
        _mockClipboard(tester, text: '123456');
        await tester.binding.setSurfaceSize(const Size(320, 640));
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: const _Harness(),
        ));
        await tester.pump();
        await tester.enterText(find.byKey(_codeKey), '123456');
        await tester.pump(const Duration(milliseconds: 300));

        final fieldBox = tester.getRect(find.byKey(_codeKey));
        expect(fieldBox.left, greaterThanOrEqualTo(0));
        expect(fieldBox.right, lessThanOrEqualTo(320));
        for (var i = 0; i < 6; i++) {
          expect(_digit(i, '123456'[i]), findsOneWidget);
        }
        expect(tester.takeException(), isNull);

        await _dispose(tester);
      });
    }
  });

  group('LoginPage code step', () {
    late List<http.Request> verifyRequests;
    late Completer<http.Response> verifyGate;

    MockClient client() => MockClient((request) async {
          if (request.url.path == '/api/auth/send-code') {
            return http.Response('{"success":true}', 200);
          }
          if (request.url.path == '/api/auth/verify-code') {
            verifyRequests.add(request);
            return verifyGate.future;
          }
          throw StateError('unexpected ${request.method} ${request.url}');
        });

    Future<void> openCodeStep(WidgetTester tester) async {
      // Created inside the test body: a Completer made in setUp would live
      // outside the fake-async zone and its continuations would never be
      // flushed by pump().
      verifyRequests = [];
      verifyGate = Completer<http.Response>();
      _mockClipboard(tester);
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: const LoginPage(startWithPhoneForm: true),
      ));
      await tester.pump();
      await tester.enterText(
          find.byKey(const ValueKey('auth-phone-input')), '+77000000000');
      await tester.tap(find.byKey(const ValueKey('request-code-button')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_codeKey), findsOneWidget);
    }

    testWidgets(
        'a pasted code fills the boxes and is submitted exactly once '
        'whichever way the user confirms', (tester) async {
      await http.runWithClient(() async {
        await openCodeStep(tester);

        await tester.enterText(find.byKey(_codeKey), '123 456');
        await tester.pump(const Duration(milliseconds: 50));

        for (var i = 0; i < 6; i++) {
          expect(_digit(i, '123456'[i]), findsOneWidget, reason: 'box $i');
        }
        expect(verifyRequests, hasLength(1));
        expect(
          jsonDecode(verifyRequests.single.body),
          {'phone_number': '+77000000000', 'onetime_code': '123456'},
        );

        // The confirm button is disabled while verifying, the keyboard's
        // "done" action and a second identical edit must not resubmit.
        await tester.tap(find.byKey(const ValueKey('confirm-code-button')));
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.enterText(find.byKey(_codeKey), '123456');
        await tester.pump();
        expect(verifyRequests, hasLength(1));

        verifyGate.complete(http.Response('{"success":false}', 401));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await _dispose(tester);
      }, client);
    });

    testWidgets('a wrong code shakes, shows the error, clears and retries',
        (tester) async {
      await http.runWithClient(() async {
        await openCodeStep(tester);

        await tester.enterText(find.byKey(_codeKey), '111111');
        await tester.pump(const Duration(milliseconds: 50));
        expect(verifyRequests, hasLength(1));
        verifyGate.complete(http.Response('{"success":false}', 401));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Неверный код или ошибка. Попробуйте ещё раз'),
            findsOneWidget);
        expect(_fieldController(tester).text, isEmpty);
        expect(_digit(0, '1'), findsNothing);
        expect(tester.takeException(), isNull);

        // Typing again removes the error and submits the new code.
        verifyGate = Completer<http.Response>();
        await tester.enterText(find.byKey(_codeKey), '222222');
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Неверный код или ошибка. Попробуйте ещё раз'),
            findsNothing);
        expect(verifyRequests, hasLength(2));
        expect(jsonDecode(verifyRequests.last.body)['onetime_code'], '222222');

        verifyGate.complete(http.Response('{"success":false}', 401));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await _dispose(tester);
      }, client);
    });

    testWidgets('an incomplete code is not submitted and keeps confirm off',
        (tester) async {
      await http.runWithClient(() async {
        await openCodeStep(tester);

        await tester.enterText(find.byKey(_codeKey), '12345');
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        expect(verifyRequests, isEmpty);
        final confirm = tester.widget<FilledButton>(find.descendant(
          of: find.byKey(const ValueKey('confirm-code-button')),
          matching: find.byType(FilledButton),
        ));
        expect(confirm.onPressed, isNull);

        await _dispose(tester);
      }, client);
    });
  });
}
