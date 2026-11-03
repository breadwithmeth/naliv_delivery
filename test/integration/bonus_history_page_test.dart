import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/bonuses/ui/bonus_history_page.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _account(num balance, {String? cardCode}) => http.Response(
      jsonEncode({
        'success': true,
        'data': {
          'totalBonuses': balance,
          if (cardCode != null) 'bonusCard': {'cardUuid': cardCode},
          'bonusHistory': [
            {
              'bonusId': 81,
              'orderId': 45,
              'amount': 1900.25,
              'timestamp': '2026-07-10T23:00:00+05:00',
            },
            {
              'bonusId': 82,
              'orderId': 45,
              'returnId': '1C-RETURN-7',
              'amount': -2100.75,
              'timestamp': '2026-07-11T12:00:00+05:00',
            },
          ],
        },
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

Future<void> _pump(
    WidgetTester tester, CartProvider cart, BonusHistoryPage page) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: cart,
    child: MaterialApp(theme: AppTheme.dark(), home: page),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auth_token': 'fixture-only'});
    await initializeDateFormatting('ru');
  });

  testWidgets('server signed ledger and balance refresh when help is closed',
      (tester) async {
    final cart = CartProvider();
    var reads = 0;
    var balance = 164.5;
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/bonuses');
      expect(request.headers['Authorization'], 'Bearer fixture-only');
      reads++;
      return _account(balance);
    });
    await http.runWithClient(() async {
      await _pump(tester, cart, BonusHistoryPage(onHowItWorks: () async {
        balance = 200.75;
      }));
      expect(find.text('164,5 бонусов', findRichText: true), findsOneWidget);
      expect(find.text('+1\u00a0900,25 бонусов'), findsOneWidget);
      expect(find.text('−2\u00a0100,75 бонусов'), findsOneWidget);
      expect(find.text('Возврат №1C-RETURN-7'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bonus-how-it-works')));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('200,75 бонусов', findRichText: true), findsOneWidget);
      expect(find.text('−2\u00a0100,75 бонусов'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    cart.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the card QR opens full screen from the balance card',
      (tester) async {
    final cart = CartProvider();
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/bonuses');
      return _account(164.5, cardCode: 'card-uuid-7');
    });
    await http.runWithClient(() async {
      await _pump(tester, cart, const BonusHistoryPage());
      await tester.tap(find.byKey(const ValueKey('bonus-qr-open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bonus-qr-page')), findsOneWidget);
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('bonus-qr-card-code')))
              .data,
          'card-uuid-7');
      expect(find.byKey(const ValueKey('bonus-qr-balance')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bonus-qr-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bonus-qr-page')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    cart.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('no card code, no QR row', (tester) async {
    final cart = CartProvider();
    final client = MockClient((request) async => _account(10));
    await http.runWithClient(() async {
      await _pump(tester, cart, const BonusHistoryPage());
      expect(find.byKey(const ValueKey('bonus-qr-open')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    cart.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('unavailable ledger is not a zero balance and retry reads server',
      (tester) async {
    final cart = CartProvider();
    var reads = 0;
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/bonuses');
      reads++;
      if (reads == 1) {
        return http.Response('{"success":true,"data":{}}', 200,
            headers: {'content-type': 'application/json'});
      }
      return _account(-5.5);
    });
    await http.runWithClient(() async {
      await _pump(tester, cart, const BonusHistoryPage());
      expect(find.text('0 бонусов', findRichText: true), findsNothing);
      expect(find.text('−5,5 бонусов', findRichText: true), findsNothing);
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('−5,5 бонусов', findRichText: true), findsOneWidget);
      expect(find.text('−2\u00a0100,75 бонусов'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    cart.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('account switch hides retained bonus data before refresh settles',
      (tester) async {
    final cart = CartProvider();
    final replacement = Completer<http.Response>();
    final client = MockClient((request) {
      if (request.method != 'GET' || request.url.path != '/api/bonuses') {
        throw StateError('Unexpected request: $request');
      }
      return request.headers['Authorization'] == 'Bearer fixture-only'
          ? Future.value(_account(164.5))
          : replacement.future;
    });
    await http.runWithClient(() async {
      try {
        await _pump(tester, cart, const BonusHistoryPage());
        expect(find.text('164,5 бонусов', findRichText: true), findsOneWidget);
        await AuthService.saveToken('replacement');
        await tester.pump();
        expect(find.text('164,5 бонусов', findRichText: true), findsNothing);
        expect(find.text('Возврат №1C-RETURN-7'), findsNothing);
        replacement.complete(_account(200.75));
        await tester.pumpAndSettle();
        expect(find.text('200,75 бонусов', findRichText: true), findsOneWidget);
      } finally {
        if (!replacement.isCompleted) replacement.complete(_account(200.75));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    }, () => client);
    client.close();
    cart.dispose();
    await AuthService.bindAuthenticatedIdentity(null);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('old bonus read cannot block or overwrite a replacement session',
      (tester) async {
    final cart = CartProvider();
    final previous = Completer<http.Response>();
    final client = MockClient((request) {
      if (request.method != 'GET' || request.url.path != '/api/bonuses') {
        throw StateError('Unexpected request: $request');
      }
      return request.headers['Authorization'] == 'Bearer fixture-only'
          ? previous.future
          : Future.value(_account(200.75));
    });
    await http.runWithClient(() async {
      try {
        await tester.binding.setSurfaceSize(const Size(375, 812));
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: cart,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const BonusHistoryPage(),
          ),
        ));
        await tester.pump();
        await AuthService.saveToken('replacement');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('200,75 бонусов', findRichText: true), findsOneWidget);
        previous.complete(_account(164.5));
        await tester.pumpAndSettle();
        expect(find.text('200,75 бонусов', findRichText: true), findsOneWidget);
        expect(find.text('164,5 бонусов', findRichText: true), findsNothing);
      } finally {
        if (!previous.isCompleted) previous.complete(_account(164.5));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    }, () => client);
    client.close();
    cart.dispose();
    await AuthService.bindAuthenticatedIdentity(null);
    await tester.binding.setSurfaceSize(null);
  });
}
